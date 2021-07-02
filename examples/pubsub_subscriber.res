/* this is pretty much the same as the examples provided in
 * node-amqp-connection-manager
 * https://github.com/benbria/node-amqp-connection-manager/blob/master/examples/pubsub-subscriber.js */

module Amqp = AmqpConnectionManager

let queue_name = "amqp-connection-manager-sample2"
let exchange_name = "amqp-connection-manager-sample2-ex"

// Handle an incomming message.
let onMessage = (channel, msg: Amqp.Queue.message) => {
  let message = msg.content->Node.Buffer.toString->Js.Json.parseExn
  Js.Console.log2("receiver: got message", message)
  Amqp.Channel.ack(channel, msg)
}

// Create a connetion manager
let connection = Amqp.connect(["amqp://localhost"], ())
Amqp.AmqpConnectionManager.on(connection, #connect(_ => Js.Console.info("Connected!")))->ignore
Amqp.AmqpConnectionManager.on(connection, #disconnect(err => Js.Console.error(err)))->ignore

// Set up a channel listening for messages in the queue.
let channelWrapper = Amqp.AmqpConnectionManager.createChannel(
  connection,
  {
    "setup": channel => {
      open // `channel` here is a regular amqplib `ConfirmChannel`.
      Js.Promise
      all([
        Amqp.Channel.assertQueue(
          channel,
          queue_name,
          {"exclusive": true, "autoDelete": true, "durable": false},
        ) |> then_(_ => resolve()),
        Amqp.Channel.assertExchange(channel, exchange_name, "topic", Js.Obj.empty()) |> then_(_ =>
          resolve()
        ),
        Amqp.Channel.prefetch(channel, 1),
        Amqp.Channel.bindQueue(channel, queue_name, exchange_name, ""),
        Amqp.Channel.consume(channel, queue_name, onMessage(channel)),
      ]) |> then_(_ => resolve())
    },
  },
)

Amqp.ChannelWrapper.waitForConnect(channelWrapper)
|> Js.Promise.then_(_ => {
  Js.Console.info("Listening for messages")
  Js.Promise.resolve()
})
|> ignore
