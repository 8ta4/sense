module Spec where

import Data.Aeson (Value)
import Network.HTTP.Req (POST (POST), ReqBodyJson (ReqBodyJson), defaultHttpConfig, jsonResponse, req, responseBody, runReq, (/:))
import Relude
import Sense (baseUrl, loadApiKeyHeader, makeRequestPayload, model)

main :: IO ()
main = do
  apiKeyHeader <- loadApiKeyHeader
  let payload = makeRequestPayload "fat" "sense" "Any of the manners by which living beings perceive the physical world: for humans sight, smell, hearing, touch, taste."
  putTextLn "Payload:"
  print payload
  putTextLn "Response:"
  response <- runReq defaultHttpConfig $ req POST (baseUrl /: "models" /: model <> ":generateContent") (ReqBodyJson payload) jsonResponse apiKeyHeader
  print (responseBody response :: Value)
