module Spec where

import Data.Yaml (Value, decodeFileEither)
import Main (Config, baseUrl, loadApiKeyHeader, makePayload, model)
import Network.HTTP.Req (POST (POST), ReqBodyJson (ReqBodyJson), defaultHttpConfig, jsonResponse, req, responseBody, runReq, (/:))
import Relude

main :: IO ()
main = do
  apiKeyHeader <- loadApiKeyHeader
  result <- decodeFileEither "fat.yaml"
  case result of
    Left _ -> pure ()
    Right (config :: Config) -> runReq defaultHttpConfig $ do
      let payload = makePayload config "strain"
      putTextLn "Payload:"
      print payload
      response <- req POST (baseUrl /: "models" /: model <> ":generateContent") (ReqBodyJson payload) jsonResponse apiKeyHeader
      putTextLn "Response:"
      print (responseBody response :: Value)
