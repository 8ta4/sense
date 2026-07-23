module Main where

import Control.Concurrent (threadDelay)
import Control.Lens (Ixed (ix), traversed)
import Control.Lens.Fold (folding, (^..), (^?))
import Data.Aeson (decodeStrict, encodeFile)
import Data.Aeson.Key (fromText)
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap (KeyMap, delete, keys)
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Aeson.Lens (key, values, _Double, _Number, _Object, _String)
import Data.Csv (DecodeOptions (decDelimiter), EncodeOptions (encDelimiter), FromNamedRecord, decodeByNameWith, defaultDecodeOptions, defaultEncodeOptions, encodeWith, parseNamedRecord, (.:))
import Data.Text (splitOn)
import Data.Vector (Vector)
import Data.Vector qualified as Vector
import Data.Yaml (FromJSON, Value, decodeFileEither, object, (.=))
import Network.HTTP.Req (GET (GET), JsonResponse, NoReqBody (NoReqBody), Option, POST (POST), Req, ReqBodyJson (ReqBodyJson), Scheme (Https), Url, defaultHttpConfig, header, https, jsonResponse, req, responseBody, runReq, (/:))
import Options.Applicative (execParser, helper, strArgument)
import Options.Applicative.Builder (info)
import Relude
import Relude.Unsafe ((!!))
import System.Directory (createDirectoryIfMissing, doesFileExist, getHomeDirectory, removeFile, renameFile)
import System.FilePath (takeBaseName, (</>))

data Row = Row
  { entry :: !Text,
    prevalence :: !Double,
    lemma :: !Bool
  }
  deriving (Show)

instance FromNamedRecord Row where
  parseNamedRecord r =
    Row
      <$> r
      .: "entry"
      <*> r
      .: "prevalence"
      <*> ((== ("true" :: Text)) <$> r .: "lemma")

data Config = Config
  { benchmark :: Text,
    theme :: Text
  }
  deriving (Generic, Show)

instance FromJSON Config

main :: IO ()
main = do
  home <- getHomeDirectory
  let statePath = home </> ".local/state/sense"
  createDirectoryIfMissing True statePath
  content <- readFileLBS "wiktionary.tsv"
  case decodeByNameWith (defaultDecodeOptions {decDelimiter = 9}) content of
    Right (_, rows :: Vector Row) -> do
      file <- execParser $ info (strArgument mempty <**> helper) mempty
      result <- decodeFileEither file
      case result of
        Left exception -> do
          putTextLn "YAML file could not be parsed"
          print exception
        Right (config :: Config) -> do
          putTextLn "YAML file parsed successfully"
          print config
          let outputJsonFile = (takeBaseName file) <> ".json"
          outputJsonExists <- doesFileExist outputJsonFile
          unless outputJsonExists $ do
            let batchIdPath = statePath </> "id"
            let cacheFile = statePath </> "cache.json"
            apiKeyHeader <- loadApiKeyHeader
            let eligibleRows =
                  Vector.filter
                    ( \row ->
                        row.prevalence >= 50 && row.lemma && config.benchmark /= row.entry
                    )
                    rows
            let loop = do
                  batchExists <- doesFileExist batchIdPath
                  progress <-
                    if batchExists
                      then do
                        cacheExists <- doesFileExist cacheFile
                        cache <-
                          if cacheExists
                            then do
                              eitherCache <- decodeFileEither cacheFile
                              case eitherCache of
                                Right cache' -> pure cache'
                                Left _ -> pure KeyMap.empty
                            else pure KeyMap.empty
                        batchId <- readFileBS batchIdPath
                        results <- poll $ req GET (baseUrl /: "batches" /: decodeUtf8 batchId) NoReqBody jsonResponse apiKeyHeader
                        let progress' = cache <> (KeyMap.fromList $ (((!! 0) <$> (filter (fromText config.benchmark /=)) <$> keys) &&& id) <$> results)
                        encodeFile cacheFile progress'
                        pure progress'
                      else pure KeyMap.empty
                  let remainingRows =
                        Vector.filter
                          ( \row ->
                              not $ KeyMap.member (fromText row.entry) progress
                          )
                          eligibleRows
                  if Vector.null remainingRows
                    then do
                      renameFile cacheFile $ outputJsonFile
                      removeFile batchIdPath
                    else runReq defaultHttpConfig $ do
                      response <-
                        req
                          POST
                          batchUrl
                          ( ReqBodyJson
                              $ object
                                [ "batch"
                                    .= object
                                      [ "input_config"
                                          .= object
                                            [ "requests"
                                                .= object
                                                  [ "requests"
                                                      .= ( ( \target ->
                                                               object
                                                                 [ "request"
                                                                     .= makePayload config target
                                                                 ]
                                                           )
                                                             <$> (.entry)
                                                             <$> Vector.take batchLimit remainingRows
                                                         )
                                                  ]
                                            ]
                                      ]
                                ]
                          )
                          jsonResponse
                          apiKeyHeader
                      case (responseBody response :: Value) ^? key "name" . _String of
                        Just name -> do
                          writeFileText batchIdPath $ (splitOn "/" name) !! 1
                          liftIO loop
                        Nothing -> pure ()
            loop
          eitherOutputJson <- decodeFileEither outputJsonFile
          case eitherOutputJson of
            Right (outputJson :: KeyMap Value) -> do
              let responses =
                    filter
                      ( \response ->
                          fromMaybe False $ and <$> ((0 <) &&& (< 100)) <$> (response ^? ix (fromText config.benchmark) . _Number)
                      )
                      $ outputJson
                      ^.. traversed . _Object
              -- We extract the score using `_Double` instead of `_Number` to safely perform division.
              -- If dividing two `Scientific` values results in a repeating decimal, it throws: "fromRational has been applied to a repeating decimal which can't be represented as a Scientific!".
              let meanBenchmarkScore = (sum $ responses ^.. traversed . ix (fromText config.benchmark) . _Double) / fromIntegral (length responses)
              writeFileLBS ((takeBaseName file) <> ".tsv")
                $ "entry\tconnection\n"
                <> encodeWith
                  defaultEncodeOptions {encDelimiter = 9}
                  ( mapMaybe
                      ( \response -> do
                          rawBenchmarkScore <- response ^? ix (fromText config.benchmark) . _Double
                          (targetKey, targetScore') <- listToMaybe $ KeyMap.toList $ delete (fromText config.benchmark) response
                          targetScore <- targetScore' ^? _Double
                          pure
                            ( Key.toText targetKey,
                              if rawBenchmarkScore < targetScore
                                then 100 - ((100 - targetScore) * (100 - meanBenchmarkScore) / (100 - rawBenchmarkScore))
                                else targetScore * meanBenchmarkScore / rawBenchmarkScore
                            )
                      )
                      responses
                  )
            Left _ -> pure ()
    Left _ -> pure ()

loadApiKeyHeader :: IO (Option 'Https)
loadApiKeyHeader = do
  home <- getHomeDirectory
  apiKey <- readFileBS $ home </> ".config/sense/key"
  pure $ header "x-goog-api-key" apiKey

makePayload :: Config -> Text -> Value
makePayload config target =
  object
    [ "contents"
        .= [ object
               [ "parts"
                   .= [ object
                          ["text" .= ("Theme:\n" <> config.theme <> "\n\nPhrases:\n" <> config.benchmark <> "\n" <> target)]
                      ]
               ]
           ],
      "generation_config"
        .= object
          [ "max_output_tokens" .= (100 :: Int),
            "response_mime_type" .= ("application/json" :: Text),
            -- Using camelCase (`responseJsonSchema`) causes the Gemini Batch API to generate incorrect properties in the output.
            -- To ensure the schema is applied correctly, we use snake_case (`response_json_schema`).
            "response_json_schema"
              .= object
                [ "additional_properties" .= False,
                  "properties"
                    .= object
                      [ fromText config.benchmark
                          .= percentageSchema,
                        fromText target
                          .= percentageSchema
                      ],
                  "property_ordering" .= [fromText config.benchmark, fromText target],
                  "required" .= [fromText config.benchmark, fromText target],
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

percentageSchema :: Value
percentageSchema =
  object
    [ "maximum" .= (100 :: Int),
      "minimum" .= (0 :: Int),
      "type" .= ("number" :: Text)
    ]

systemPrompt :: Text
systemPrompt = "Estimate the percentage of Americans 10 years or older who would understand a joke connecting the phrase to the theme."

poll :: Req (JsonResponse Value) -> IO [KeyMap Value]
poll request = runReq defaultHttpConfig $ do
  response <- request
  case (responseBody response) ^? key "metadata" . key "state" . _String of
    Just "BATCH_STATE_SUCCEEDED" ->
      pure $ (responseBody response)
        ^.. key "response"
          . key "inlinedResponses"
          . key "inlinedResponses"
          . values
          . key "response"
          . key "candidates"
          . values
          . key "content"
          . key "parts"
          . values
          . key "text"
          . _String
          . folding (decodeStrict . encodeUtf8 :: Text -> Maybe Value)
          . _Object
    Just "BATCH_STATE_RUNNING" -> liftIO $ do
      threadDelay 10000000
      poll request
    Just _ -> pure []
    Nothing -> pure []

batchUrl :: Url 'Https
batchUrl = baseUrl /: "models" /: model <> ":batchGenerateContent"

baseUrl :: Url 'Https
baseUrl = https "generativelanguage.googleapis.com" /: "v1beta"

model :: Text
model = "gemini-3.6-flash"

batchLimit :: Int
batchLimit = 2 ^ (16 :: Int)
