module Main (main) where

import Data.Csv (DecodeOptions (decDelimiter), FromNamedRecord, decodeByNameWith, defaultDecodeOptions, parseNamedRecord, (.:))
import Data.Vector (Vector)
import Data.Yaml (FromJSON, decodeFileEither)
import Options.Applicative (execParser, helper, strArgument)
import Options.Applicative.Builder (info)
import Relude
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
  key <- readFileBS $ home </> ".config/sense/key"
  createDirectoryIfMissing True $ home </> ".local/state/sense/"
  content <- readFileLBS "wiktionary.tsv"
  case decodeByNameWith (defaultDecodeOptions {decDelimiter = 9}) content of
    Left _ -> pure ()
    Right (_, rows :: Vector Row) -> pure ()
  file <- execParser $ info (strArgument mempty <**> helper) mempty
  result <- decodeFileEither file
  case result of
    Left exception -> do
      putTextLn "YAML file could not be parsed"
      print exception
    Right (config :: Config) -> do
      putTextLn "YAML file parsed successfully"
      print config
