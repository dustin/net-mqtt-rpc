{-# LANGUAGE BlockArguments    #-}
{-# LANGUAGE NamedFieldPuns    #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards   #-}

module Network.MQTT.RPC (call) where

import           Control.Concurrent.STM (atomically, newTChanIO, readTChan,
                                         writeTChan)
import           Control.Monad          (when)
import           Control.Monad.Catch    (bracket, throwM)
import           Control.Monad.IO.Class (MonadIO (..))
import qualified Data.ByteString.Lazy   as BL
import           Data.Text              (Text)
import qualified Data.Text.Encoding     as TE
import qualified Data.UUID              as UUID
import           Network.MQTT.Client
import           System.Random          (randomIO)

blToText :: BL.ByteString -> Text
blToText = TE.decodeUtf8 . BL.toStrict

-- | Send a message to a topic on an MQTT broker with a random
-- subscription and correlation such that an agent may receive this
-- message and respond over the ephemeral channel.  The response will
-- be returned.
--
-- Note that this client provides no timeouts or retries.  MQTT will
-- guarantee the request message is delivered to the broker, but if
-- there's nothing to pick it up, there may never be a response.
call :: MonadIO m => MQTTClient -> Topic -> BL.ByteString -> m BL.ByteString
call mc topic req = liftIO do
  r <- newTChanIO
  corr <- BL.fromStrict . UUID.toASCIIBytes <$> randomIO
  subid <- BL.fromStrict . ("$rpc/" <>) . UUID.toASCIIBytes <$> randomIO
  go corr subid r

  where go theID theTopic r = bracket reg unreg rt
          where reg = do
                  atomically $ registerCorrelated mc theID (SimpleCallback cb)
                  subscribe mc [(blToText theTopic, subOptions)] mempty
                unreg _ = do
                  atomically $ unregisterCorrelated mc theID
                  unsubscribe mc [blToText theTopic] mempty
                cb _ _ m _ = atomically $ writeTChan r m
                rt _ = do
                  publishq mc topic req False QoS2 [
                    PropCorrelationData theID,
                    PropResponseTopic theTopic]
                  atomically do
                    connd <- isConnectedSTM mc
                    when (not connd) $ throwM (MQTTException "disconnected")
                    readTChan r
