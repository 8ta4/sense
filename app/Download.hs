module Download where

import Control.Lens ((^..))
import Data.Aeson (FromJSON, ToJSON)
import Data.Aeson.Lens (key, values, _JSON)
import Relude
import System.Directory (createDirectoryIfMissing, getHomeDirectory)
import System.FilePath ((</>))
import System.Process (callProcess)

data Part = Part
  { url :: !Text,
    hash :: !Text
  }
  deriving (Show, ToJSON, FromJSON, Generic)

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
  let parts :: [Part] = content ^.. key "parts" . values . _JSON
  pure ()

manifestUrl :: String
manifestUrl = "https://raw.githubusercontent.com/8ta4/mean-data/0a69fe730a0ea1bfaef84eba0dbe0f68ce991683/manifest.json"
