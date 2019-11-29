{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE RecordWildCards     #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Main where

import           Control.Monad        (when)
import qualified Data.ByteString.Lazy as BL
import           Data.Maybe           (fromJust)
import           Network.MQTT.Client
import           Network.MQTT.RPC
import           Network.URI
import           Options.Applicative  (Parser, execParser, fullDesc, help,
                                       helper, info, long, maybeReader, option,
                                       progDesc, short, showDefault, strOption,
                                       switch, value, (<**>))
import           System.IO            (stdout)

data Options = Options {
  optUri     :: URI
  , optTopic :: Topic
  , optMsg   :: BL.ByteString
  , optNL    :: Bool
  }

options :: Parser Options
options = Options
  <$> option (maybeReader parseURI) (long "mqtt-uri" <> short 'u' <> showDefault <> value (fromJust $ parseURI "mqtt://localhost/") <> help "mqtt broker URI")
  <*> strOption (long "mqtt-topic" <> short 't' <> showDefault <> value "tmp/rpctest" <> help "MQTT request topic")
  <*> strOption (long "mqtt-msg" <> short 'm' <> showDefault <> value "" <> help "Request Message")
  <*> switch (long "newline" <> help "add a newline after outputting the message")

run :: Options -> IO ()
run Options{..} = do
  mc <- connectURI mqttConfig{_protocol=Protocol50} optUri
  BL.hPut stdout =<< call mc optTopic optMsg
  when optNL $ putStrLn ""

main :: IO ()
main = run =<< execParser opts

  where opts = info (options <**> helper) (fullDesc <> progDesc "RPC test")
