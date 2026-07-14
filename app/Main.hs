module Main (main) where

import Data.Yaml (FromJSON, decodeFileEither)
import Options.Applicative (execParser, helper, strArgument)
import Options.Applicative.Builder (info)
import Relude

data Config = Config
  { benchmark :: Text,
    theme :: Text
  }
  deriving (Generic, Show)

instance FromJSON Config

main :: IO ()
main = do
  file <- execParser $ info (strArgument mempty <**> helper) mempty
  result <- decodeFileEither file
  case result of
    Left exception -> do
      putTextLn "YAML file could not be parsed"
      print exception
    Right (config :: Config) -> do
      putTextLn "YAML file parsed successfully"
      print config
  pure ()
