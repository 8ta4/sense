module Sense where

import Control.Lens ((^..), (^?))
import Control.Lens.Cons (_last)
import Data.Aeson (KeyValue ((.=)), ToJSON, Value, decode, decodeFileStrict, encode, object)
import Data.Aeson.Key (fromText)
import Data.Aeson.Lens (key, values, _Array, _String)
import Data.ByteString.Lazy.Char8 qualified as Char8
import Data.List ((!!))
import Data.Map qualified as Map
import Data.Text (splitOn)
import Data.Text qualified as Text
import Network.HTTP.Req (HttpConfig (httpConfigRetryPolicy), Option, POST (POST), ReqBodyFile (ReqBodyFile), ReqBodyJson (ReqBodyJson), Scheme (Https), Url, defaultHttpConfig, header, https, ignoreResponse, jsonResponse, req, responseBody, responseHeader, responseTimeout, runReq, useHttpsURI, (/:))
import Options.Applicative (execParser, helper, strArgument)
import Options.Applicative.Builder (info)
import Path (getStatePath, getWiktextractPath, meanFilename)
import Relude
import System.Directory (doesFileExist, getFileSize, getHomeDirectory, getTemporaryDirectory)
import System.FilePath ((</>))
import Text.URI (mkURI)

main :: IO ()
main = do
  statePath <- getStatePath
  let meanPath = statePath </> toString meanFilename
      batchIdPath = statePath </> "id"
  batchExists <- doesFileExist batchIdPath
  wiktextractPath <- getWiktextractPath
  temporaryDirectory <- getTemporaryDirectory
  let inputPath = temporaryDirectory </> "input.jsonl"
  targetTopic <- execParser $ info (strArgument mempty <**> helper) mempty
  apiKeyHeader <- loadApiKeyHeader
  maybeMeanScores <- decodeFileStrict meanPath
  case maybeMeanScores of
    Just (meanScores :: Map Text (Map Text Double)) -> do
      let ensureSubmitted = unless batchExists $ do
            content <- readFileLBS wiktextractPath
            writeFileLBS inputPath $ Char8.unlines $ makeBatchLine targetTopic <$> ordNub ((filter isTarget $ mapMaybe decode $ Char8.lines content) >>= processEntry)
            fileSize <- getFileSize inputPath
            let initialHeaders =
                  apiKeyHeader
                    <> header "X-Goog-Upload-Protocol" "resumable"
                    <> header "X-Goog-Upload-Command" "start"
                    <> header "X-Goog-Upload-Header-Content-Length" (show fileSize)
                    <> header "X-Goog-Upload-Header-Content-Type" "application/json"
            initialResponse <-
              runReq defaultHttpConfig
                $ req
                  POST
                  (host /: "upload" /: "v1beta" /: "files")
                  (ReqBodyJson $ object [])
                  ignoreResponse
                  initialHeaders
            case responseHeader initialResponse "x-goog-upload-url" of
              Just uploadUrlHeader -> do
                uploadUri <- mkURI $ decodeUtf8 uploadUrlHeader
                case useHttpsURI uploadUri of
                  Just (uploadUrl, uploadOptions) -> do
                    uploadResponse <-
                      runReq defaultHttpConfig
                        $ req
                          POST
                          uploadUrl
                          (ReqBodyFile inputPath)
                          jsonResponse
                          ( apiKeyHeader
                              <> header "X-Goog-Upload-Offset" "0"
                              <> header "X-Goog-Upload-Command" "upload, finalize"
                              <> uploadOptions
                          )
                    case (responseBody uploadResponse :: Value) ^? key "file" . key "name" . _String of
                      Just filename -> do
                        batchResponse <-
                          -- Disabling retries prevents submitting multiple batches and getting charged multiple times.
                          runReq (defaultHttpConfig {httpConfigRetryPolicy = mempty})
                            $ req
                              POST
                              batchUrl
                              (ReqBodyJson $ makeBatchPayload filename)
                              jsonResponse
                              -- The API may take 30+ seconds to respond when submitting a batch request.
                              (apiKeyHeader <> responseTimeout timeout)
                        case (responseBody batchResponse :: Value) ^? key "name" . _String of
                          Just batchName -> writeFileText batchIdPath $ (splitOn "/" batchName) !! 1
                          _ -> pure ()
                      _ -> pure ()
                  _ -> pure ()
              _ -> pure ()
          processEntry entry = fromMaybe [] $ do
            phrase <- entry ^? key "word" . _String
            meaningScores <- Map.lookup phrase meanScores
            let senses = entry ^.. key "senses" . values
                hasKnownIdiom = any (\sense -> isKnown meaningScores sense && isIdiomatic sense) senses
            pure
              $ (phrase,)
              <$> ( ( if hasKnownIdiom && not (any isLiteral senses)
                        then (syntheticLiteral :)
                        else id
                    )
                      $ mapMaybe extractMeaning
                      $ filter
                        ( \sense ->
                            isKnown meaningScores sense
                              && ( Map.size (Map.filter isKnown' meaningScores)
                                     > 1
                                     || isIdiomatic sense
                                 )
                              || hasKnownIdiom
                              && isLiteral sense
                        )
                      $ senses
                  )
      ensureSubmitted
    _ -> pure ()

isTarget :: Value -> Bool
isTarget entry = isEnglish entry && isNotBenchmark entry

isEnglish :: Value -> Bool
isEnglish entry = case entry ^? key "lang" . _String of
  Just "English" -> True
  _ -> False

isNotBenchmark :: Value -> Bool
isNotBenchmark entry = case entry ^? key "word" . _String of
  Just phrase -> benchmarkPhrase /= phrase
  _ -> False

benchmarkPhrase :: Text
benchmarkPhrase = "dog"

loadApiKeyHeader :: IO (Option 'Https)
loadApiKeyHeader = do
  home <- getHomeDirectory
  apiKey <- readFileBS $ home </> ".config/sense/key"
  pure $ header "x-goog-api-key" apiKey

makeRequestPayload :: Text -> Text -> Text -> Value
makeRequestPayload targetTopic targetPhrase targetMeaning =
  object
    [ "contents"
        .= [ object
               [ "parts"
                   .= [ object
                          ["text" .= (renderEdn benchmarkTopic benchmarkPhrase benchmarkMeaning <> "\n" <> renderEdn targetTopic targetPhrase targetMeaning)]
                      ]
               ]
           ],
      "generation_config"
        .= object
          [ "max_output_tokens" .= (2 :: Int) ^ (7 :: Int),
            "response_mime_type" .= ("application/json" :: Text),
            -- Using camelCase (`responseJsonSchema`) causes the Gemini Batch API to generate incorrect properties in the output.
            -- To ensure the schema is applied correctly, we use snake_case (`response_json_schema`).
            "response_json_schema"
              .= object
                [ "additional_properties" .= False,
                  "properties"
                    .= object
                      [ fromText benchmarkPhrase
                          .= percentageSchema,
                        fromText targetPhrase
                          .= percentageSchema
                      ],
                  "property_ordering" .= [fromText benchmarkPhrase, fromText targetPhrase],
                  "required" .= [fromText benchmarkPhrase, fromText targetPhrase],
                  "type" .= ("object" :: Text)
                ],
            "seed" .= (0 :: Int),
            "temperature" .= (0 :: Int),
            "thinking_config"
              .= object
                ["thinking_level" .= ("MINIMAL" :: Text)]
          ],
      "system_instruction"
        .= object
          [ "parts"
              .= [ object
                     ["text" .= systemPrompt]
                 ]
          ]
    ]

-- Haskell's `show` escapes non-ASCII Unicode characters using decimal escape sequences.
-- `renderJson` uses JSON string escaping.
renderEdn :: Text -> Text -> Text -> Text
renderEdn topic phrase meaning = "{:phrase " <> renderJson phrase <> " :meaning " <> renderJson meaning <> " :topic " <> renderJson topic <> "}"

renderJson :: (ToJSON a) => a -> Text
renderJson = decodeUtf8 <$> encode

benchmarkMeaning :: Text
benchmarkMeaning = "A dull, unattractive girl or woman."

benchmarkTopic :: Text
benchmarkTopic = "ugly"

percentageSchema :: Value
percentageSchema =
  object
    [ "maximum" .= (100 :: Int),
      "minimum" .= (0 :: Int),
      "type" .= ("number" :: Text)
    ]

systemPrompt :: Text
systemPrompt = "Estimate the percentage of Americans 10 years or older who consider each meaning on topic."

batchUrl :: Url 'Https
batchUrl = baseUrl /: "models" /: model <> ":batchGenerateContent"

baseUrl :: Url 'Https
baseUrl = host /: "v1beta"

host :: Url 'Https
host = https "generativelanguage.googleapis.com"

model :: Text
model = "gemini-3.6-flash"

makeBatchPayload :: Text -> Value
makeBatchPayload filename =
  object
    [ "batch"
        .= object
          [ "input_config"
              .= object
                ["file_name" .= filename]
          ]
    ]

timeout :: Int
timeout = 24 * 60 * 60 * 10 ^ (6 :: Int)

makeBatchLine :: Text -> (Text, Text) -> Char8.ByteString
makeBatchLine topic (phrase, meaning) =
  encode
    $ object
      [ "key" .= renderJson [phrase, meaning],
        "request" .= makeRequestPayload topic phrase meaning
      ]

isKnown :: Map Text Double -> Value -> Bool
isKnown scores sense = fromMaybe False $ do
  meaning <- extractMeaning sense
  score <- Map.lookup meaning scores
  pure $ isKnown' score

isKnown' :: Double -> Bool
isKnown' = (>= 50)

isIdiomatic :: Value -> Bool
isIdiomatic sense = elem "idiomatic" $ sense ^.. key "tags" . values . _String

isLiteral :: Value -> Bool
isLiteral sense = fromMaybe False $ do
  meaning <- extractMeaning sense
  pure $ Text.isPrefixOf literalPrefix meaning

syntheticLiteral :: Text
syntheticLiteral = literalPrefix <> "."

literalPrefix :: Text
literalPrefix = "Used other than figuratively or idiomatically"

extractMeaning :: Value -> Maybe Text
extractMeaning sense = sense ^? key "glosses" . _Array . _last . _String
