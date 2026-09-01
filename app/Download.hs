module Download where

import Relude
import System.Directory (createDirectoryIfMissing, getHomeDirectory)
import System.FilePath ((</>))

main :: IO ()
main = do
  home <- getHomeDirectory
  let statePath = home </> ".local/state/sense"
      partsPath = statePath </> "parts"
      extractedPath = statePath </> "raw-wiktextract-data.jsonl"
  createDirectoryIfMissing True partsPath
  pure ()
