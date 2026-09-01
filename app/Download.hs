module Download where

import Relude
import System.Directory (createDirectoryIfMissing, getHomeDirectory)
import System.FilePath ((</>))
import System.Process (callProcess)

main :: IO ()
main = do
  home <- getHomeDirectory
  let statePath = home </> ".local/state/sense"
      partsPath = statePath </> "parts"
      manifestPath = statePath </> "manifest.json"
      extractedPath = statePath </> "raw-wiktextract-data.jsonl"
  createDirectoryIfMissing True partsPath
  callProcess "wget" ["-O", manifestPath, manifestUrl]
  content <- readFileLBS manifestPath
  pure ()

manifestUrl :: String
manifestUrl = "https://raw.githubusercontent.com/8ta4/mean-data/0a69fe730a0ea1bfaef84eba0dbe0f68ce991683/manifest.json"
