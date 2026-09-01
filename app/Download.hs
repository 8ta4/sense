module Download where

import Relude
import System.Directory (getHomeDirectory)
import System.FilePath ((</>))

main :: IO ()
main = do
  home <- getHomeDirectory
  let statePath = home </> ".local/state/sense"
      partsPath = statePath </> "parts"
      extractedPath = statePath </> "raw-wiktextract-data.jsonl"
  pure ()
