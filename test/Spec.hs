module Spec where

import Relude
import Sense (loadApiKeyHeader, makeRequestPayload)

main :: IO ()
main = do
  apiKeyHeader <- loadApiKeyHeader
  let payload = makeRequestPayload "fat" "sense" "Any of the manners by which living beings perceive the physical world: for humans sight, smell, hearing, touch, taste."
  putTextLn "Payload:"
  print payload
  pure ()
