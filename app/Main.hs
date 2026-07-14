module Main (main) where

import Options.Applicative (execParser, helper, strArgument)
import Options.Applicative.Builder (info)
import Relude

main :: IO ()
main = do
  file <- execParser $ info (strArgument mempty <**> helper) mempty
  pure ()
