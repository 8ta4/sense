module Sense where

import Data.Aeson (KeyValue ((.=)), ToJSON, Value, encode, object)
import Data.Aeson.Key
import Network.HTTP.Req (Option, Scheme (Https), Url, header, https, (/:))
import Options.Applicative (execParser, helper, strArgument)
import Options.Applicative.Builder (info)
import Path (getMeanPath, getStatePath, getWiktextractPath)
import Relude
import System.Directory (getHomeDirectory)
import System.FilePath ((</>))

main :: IO ()
main = do
  statePath <- getStatePath
  meanPath <- getMeanPath
  wiktextractPath <- getWiktextractPath
  targetTopic <- execParser $ info (strArgument mempty <**> helper) mempty
  pure ()

loadApiKeyHeader :: IO (Option 'Https)
loadApiKeyHeader = do
  home <- getHomeDirectory
  apiKey <- readFileBS $ home </> ".config/sense/key"
  pure $ header "x-goog-api-key" apiKey

makeRequestPayload :: Text -> Text -> Text -> Value
makeRequestPayload targetTopic targetPhrase targetMeaning =
  object
    [ "contents"
        .= [ object
               [ "parts"
                   .= [ object
                          ["text" .= (renderEdn benchmarkTopic benchmarkPhrase benchmarkMeaning <> "\n" <> renderEdn targetTopic targetPhrase targetMeaning)]
                      ]
               ]
           ],
      "generation_config"
        .= object
          [ "max_output_tokens" .= (2 :: Int) ^ (7 :: Int),
            "response_mime_type" .= ("application/json" :: Text),
            -- Using camelCase (`responseJsonSchema`) causes the Gemini Batch API to generate incorrect properties in the output.
            -- To ensure the schema is applied correctly, we use snake_case (`response_json_schema`).
            "response_json_schema"
              .= object
                [ "additional_properties" .= False,
                  "properties"
                    .= object
                      [ fromText benchmarkPhrase
                          .= percentageSchema,
                        fromText targetPhrase
                          .= percentageSchema
                      ],
                  "property_ordering" .= [fromText benchmarkPhrase, fromText targetPhrase],
                  "required" .= [fromText benchmarkPhrase, fromText targetPhrase],
                  "type" .= ("object" :: Text)
                ],
            "seed" .= (0 :: Int),
            "temperature" .= (0 :: Int),
            "thinking_config"
              .= object
                ["thinking_level" .= ("MINIMAL" :: Text)]
          ],
      "system_instruction"
        .= object
          [ "parts"
              .= [ object
                     ["text" .= systemPrompt]
                 ]
          ]
    ]

-- Haskell's `show` escapes non-ASCII Unicode characters using decimal escape sequences.
-- `renderJson` uses JSON string escaping.
renderEdn :: Text -> Text -> Text -> Text
renderEdn topic phrase meaning = "{:phrase " <> renderJson phrase <> " :meaning " <> renderJson meaning <> " :topic " <> renderJson topic <> "}"

renderJson :: (ToJSON a) => a -> Text
renderJson = decodeUtf8 <$> encode

benchmarkPhrase :: Text
benchmarkPhrase = "dog"

benchmarkMeaning :: Text
benchmarkMeaning = "A dull, unattractive girl or woman."

benchmarkTopic :: Text
benchmarkTopic = "ugly"

percentageSchema :: Value
percentageSchema =
  object
    [ "maximum" .= (100 :: Int),
      "minimum" .= (0 :: Int),
      "type" .= ("number" :: Text)
    ]

systemPrompt :: Text
systemPrompt = "Estimate the percentage of Americans 10 years or older who consider each meaning on topic."

baseUrl :: Url 'Https
baseUrl = host /: "v1beta"

host :: Url 'Https
host = https "generativelanguage.googleapis.com"

model :: Text
model = "gemini-3.6-flash"
