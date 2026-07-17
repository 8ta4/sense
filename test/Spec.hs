module Spec where

import Data.Yaml (Value, decodeFileEither)
import Main (Config, baseUrl, loadApiKeyHeader, makePayload)
import Network.HTTP.Req (POST (POST), ReqBodyJson (ReqBodyJson), defaultHttpConfig, jsonResponse, req, responseBody, runReq, (/:))
import Relude

main :: IO ()
main = do
  apiKeyHeader <- loadApiKeyHeader
  result <- decodeFileEither "fat.yaml"
  case result of
    Left _ -> pure ()
    Right (config :: Config) -> runReq defaultHttpConfig $ do
      response <- req POST (baseUrl /: "models" /: "gemini-3.5-flash:generateContent") (ReqBodyJson (makePayload config "strain")) jsonResponse apiKeyHeader
      liftIO $ print (responseBody response :: Value)
