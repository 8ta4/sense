module Download where

import Codec.Compression.GZip (decompress)
import Control.Lens ((^..))
import Crypto.Hash.SHA256 (hashlazy)
import Data.Aeson (FromJSON, ToJSON)
import Data.Aeson.Lens (key, values, _JSON)
import Data.ByteString.Base16 qualified as Base16
import Relude
import System.Directory (createDirectoryIfMissing, getHomeDirectory)
import System.FilePath (takeFileName, (</>))
import System.Process (callProcess)

data Part = Part
  { url :: !String,
    hash :: !Text
  }
  deriving (Show, ToJSON, FromJSON, Generic)

main :: IO ()
main = do
  home <- getHomeDirectory
  let statePath = home </> ".local/state/sense"
      partsPath = statePath </> "parts"
      meanPath = statePath </> toString meanFilename
      manifestPath = statePath </> toString manifestFilename
      extractedPath = statePath </> "raw-wiktextract-data.jsonl"
      downloadPart part = do
        let partPath = partsPath </> takeFileName part.url
        callProcess "wget" ["-cO", partPath, part.url]
        partContent <- readFileLBS partPath
        if part.hash == (decodeUtf8 $ Base16.encode $ hashlazy partContent)
          then pure partContent
          else error "Checksum verification failed"
  createDirectoryIfMissing True partsPath
  callProcess "wget" ["-O", meanPath, meanUrl]
  callProcess "unzstd" [meanPath]
  callProcess "wget" ["-O", manifestPath, manifestUrl]
  manifestContent <- readFileLBS manifestPath
  let parts :: [Part] = manifestContent ^.. key "parts" . values . _JSON
  partContents <- traverse downloadPart parts
  writeFileLBS extractedPath $ decompress $ fold partContents

meanUrl :: String
meanUrl = toString $ baseUrl <> meanFilename

baseUrl :: Text
baseUrl = "https://raw.githubusercontent.com/8ta4/mean-data/0a69fe730a0ea1bfaef84eba0dbe0f68ce991683/"

meanFilename :: Text
meanFilename = "mean.json.zst"

manifestUrl :: String
manifestUrl = toString $ baseUrl <> manifestFilename

manifestFilename :: Text
manifestFilename = "manifest.json"
