module Sense where

import Network.HTTP.Req (Option, Scheme (Https), header)
import Relude
import System.Directory (getHomeDirectory)
import System.FilePath ((</>))

main :: IO ()
main = pure ()

loadApiKeyHeader :: IO (Option 'Https)
loadApiKeyHeader = do
  home <- getHomeDirectory
  apiKey <- readFileBS $ home </> ".config/sense/key"
  pure $ header "x-goog-api-key" apiKey
