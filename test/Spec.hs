module Spec where

import Relude
import Sense (loadApiKeyHeader)

main :: IO ()
main = do
  apiKeyHeader <- loadApiKeyHeader
  pure ()
