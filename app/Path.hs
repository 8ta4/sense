module Path where

import Relude
import System.Directory (getHomeDirectory)
import System.FilePath ((</>))

getStatePath :: IO FilePath
getStatePath = do
  home <- getHomeDirectory
  pure $ home </> ".local/state/sense"

meanFilename :: Text
meanFilename = "mean.json"

getWiktextractPath :: IO FilePath
getWiktextractPath = do
  statePath <- getStatePath
  pure $ statePath </> "raw-wiktextract-data.jsonl"
