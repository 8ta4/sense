module Main where

import Control.Concurrent (threadDelay)
import Control.Lens.Fold ((^?))
import Data.Aeson.Key (fromText)
import Data.Aeson.Lens (key, _String)
import Data.Csv (DecodeOptions (decDelimiter), FromNamedRecord, decodeByNameWith, defaultDecodeOptions, parseNamedRecord, (.:))
import Data.Text (splitOn)
import Data.Vector (Vector)
import Data.Vector qualified as Vector
import Data.Yaml (FromJSON, Value, decodeFileEither, object, (.=))
import Network.HTTP.Req (GET (GET), JsonResponse, NoReqBody (NoReqBody), Option, POST (POST), Req, ReqBodyJson (ReqBodyJson), Scheme (Https), Url, defaultHttpConfig, header, https, jsonResponse, req, responseBody, runReq, (/:))
import Options.Applicative (execParser, helper, strArgument)
import Options.Applicative.Builder (info)
import Relude
import Relude.Unsafe ((!!))
import System.Directory (createDirectoryIfMissing, doesFileExist, getHomeDirectory)
import System.FilePath ((</>))

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
  let batchIdPath = statePath </> "id"
  apiKeyHeader <- loadApiKeyHeader
  exists <- doesFileExist batchIdPath
  when exists $ do
    batchId <- readFileBS batchIdPath
    poll $ req GET (baseUrl /: "batches" /: decodeUtf8 batchId) NoReqBody jsonResponse apiKeyHeader
  content <- readFileLBS "wiktionary.tsv"
  case decodeByNameWith (defaultDecodeOptions {decDelimiter = 9}) content of
    Right (_, rows :: Vector Row) -> do
      let candidates = Vector.filter isCandidate rows
      file <- execParser $ info (strArgument mempty <**> helper) mempty
      result <- decodeFileEither file
      case result of
        Left exception -> do
          putTextLn "YAML file could not be parsed"
          print exception
        Right (config :: Config) -> do
          putTextLn "YAML file parsed successfully"
          print config
          runReq defaultHttpConfig $ do
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
                                            .= ( ( \candidate ->
                                                     [ object
                                                         [ "request"
                                                             .= makePayload config candidate.entry
                                                         ]
                                                     ]
                                                 )
                                                   <$> Vector.take batchLimit candidates
                                               )
                                        ]
                                  ]
                            ]
                      ]
                )
                jsonResponse
                apiKeyHeader
            case (responseBody response :: Value) ^? key "name" . _String of
              Just name -> writeFileText batchIdPath $ (splitOn "/" name) !! 1
              Nothing -> pure ()
    Left _ -> pure ()

loadApiKeyHeader :: IO (Option 'Https)
loadApiKeyHeader = do
  home <- getHomeDirectory
  apiKey <- readFileBS $ home </> ".config/sense/key"
  pure $ header "x-goog-api-key" apiKey

makePayload :: Config -> Text -> Value
makePayload config input =
  object
    [ "contents"
        .= [ object
               [ "parts"
                   .= [ object
                          ["text" .= ("Theme:\n" <> config.theme <> "\n\nPhrases:\n" <> config.benchmark <> "\n" <> input)]
                      ]
               ]
           ],
      "generationConfig"
        .= object
          [ "maxOutputTokens" .= (100 :: Int),
            "responseMimeType" .= ("application/json" :: Text),
            "responseJsonSchema"
              .= object
                [ "properties"
                    .= object
                      [ fromText config.benchmark
                          .= percentageSchema,
                        fromText input
                          .= percentageSchema
                      ],
                  "propertyOrdering" .= [fromText config.benchmark, fromText input],
                  "type" .= ("object" :: Text)
                ],
            "seed" .= (0 :: Int),
            "temperature" .= (0 :: Int),
            "thinkingConfig"
              .= object
                ["thinkingLevel" .= ("MINIMAL" :: Text)]
          ],
      "systemInstruction"
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
systemPrompt = "Estimate the percentage of Americans 10 years or older who know each phrase's meaning that fits the theme."

poll :: Req (JsonResponse Value) -> IO ()
poll request = runReq defaultHttpConfig $ do
  response <- request
  case (responseBody response) ^? key "metadata" . key "state" . _String of
    Just "BATCH_STATE_SUCCEEDED" -> pure ()
    Just "BATCH_STATE_RUNNING" -> liftIO $ do
      threadDelay 10000000
      poll request
    Just _ -> pure ()
    Nothing -> pure ()

isCandidate :: Row -> Bool
isCandidate row = row.prevalence >= 50 && row.lemma

batchUrl :: Url 'Https
batchUrl = baseUrl /: "models" /: "gemini-3.5-flash:batchGenerateContent"

baseUrl :: Url 'Https
baseUrl = https "generativelanguage.googleapis.com" /: "v1beta"

batchLimit :: Int
batchLimit = 2 ^ (16 :: Int)
