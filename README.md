# mqtt-rpc

This package provides an RPC client interface over MQTT.

It's currently quite low-level and not very configurable, but I'm
using it in a real application, so it at least needs to work for me.
:)

## Example:

```haskell
  mc <- connectURI mqttConfig{_protocol=Protocol50} "mqtt://broker/"
  response <- call mc "some/path" "a message"
  BL.hPut stdout response
```
