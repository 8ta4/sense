module Sense where

import Data.Aeson (ToJSON, encode)
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

-- Haskell's `show` escapes non-ASCII Unicode characters using decimal escape sequences.
-- `renderJson` uses JSON string escaping.
renderEdn :: Text -> Text -> Text -> Text
renderEdn phrase meaning topic = "{:phrase " <> renderJson phrase <> " :meaning " <> renderJson meaning <> " :topic " <> renderJson topic <> "}"

renderJson :: (ToJSON a) => a -> Text
renderJson = decodeUtf8 <$> encode
