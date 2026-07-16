module Main (main) where

import Control.Lens.Fold ((^?))
import Data.Aeson.Lens (key, _String)
import Data.Csv (DecodeOptions (decDelimiter), FromNamedRecord, decodeByNameWith, defaultDecodeOptions, parseNamedRecord, (.:))
import Data.Text (splitOn)
import Data.Vector (Vector)
import Data.Vector qualified as Vector
import Data.Yaml (FromJSON, Value, decodeFileEither, object, (.=))
import Network.HTTP.Req (POST (POST), ReqBodyJson (ReqBodyJson), Scheme (Https), Url, defaultHttpConfig, header, https, jsonResponse, req, responseBody, runReq, (/:))
import Options.Applicative (execParser, helper, strArgument)
import Options.Applicative.Builder (info)
import Relude
import Relude.Unsafe ((!!))
import System.Directory (createDirectoryIfMissing, getHomeDirectory)
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
  apiKey <- readFileBS $ home </> ".config/sense/key"
  systemPrompt <- readFileBS "system.txt"
  let statePath = home </> ".local/state/sense"
  createDirectoryIfMissing True statePath
  content <- readFileLBS "wiktionary.tsv"
  file <- execParser $ info (strArgument mempty <**> helper) mempty
  result <- decodeFileEither file
  case decodeByNameWith (defaultDecodeOptions {decDelimiter = 9}) content of
    Right (_, rows :: Vector Row) -> do
      let _ = Vector.filter isCandidate rows
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
                url
                ( ReqBodyJson
                    $ object
                      [ "batch"
                          .= object
                            [ "input_config"
                                .= object
                                  [ "requests"
                                      .= object
                                        [ "requests"
                                            .= [ object
                                                   [ "request"
                                                       .= object
                                                         [ "contents"
                                                             .= [ object
                                                                    []
                                                                ],
                                                           "generationConfig"
                                                             .= object
                                                               ["maxOutputTokens" .= (100 :: Int)]
                                                         ]
                                                   ]
                                               ]
                                        ]
                                  ]
                            ]
                      ]
                )
                jsonResponse
                $ header "x-goog-api-key" apiKey
            case (responseBody response :: Value) ^? key "name" . _String of
              Just name -> writeFileText (statePath </> "id") $ (splitOn "/" name) !! 1
              Nothing -> pure ()
    Left _ -> pure ()

isCandidate :: Row -> Bool
isCandidate row = row.prevalence >= 50 && row.lemma

url :: Url 'Https
url = https "generativelanguage.googleapis.com" /: "v1beta" /: "models" /: "gemini-3.5-flash:batchGenerateContent"
