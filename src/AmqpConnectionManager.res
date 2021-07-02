type url = string
type urls = array<url>

exception ConnectionError(Js.Exn.t)

module Queue = {
  type name = string
  type rec message = {
    fields: fields,
    content: content,
  }
  and content = Node.Buffer.t
  and fields = {
    deliveryTag: int,
    redelivered: bool,
    exchange: string,
    routingKey: string,
    messageCount: option<int>,
    consumerTag: option<string>,
  }
}

module Exchange = {
  type name = string
}

module Channel = {
  type t
  type name = string
  type ack = Queue.message => unit
  type nack = Queue.message => unit

  @send external ack: (t, Queue.message) => unit = "ack"
  @send external nack: (t, Queue.message) => unit = "nack"

  module Config = {
    type t<'a> = {.."setup": t => Js.Promise.t<unit>} as 'a
  }

  @send
  external assertExchange: (t, Exchange.name, string, 'options) => Js.Promise.t<Exchange.name> =
    "assertExchange"

  @send
  external assertQueue: (
    t,
    Queue.name,
    'options,
  ) => Js.Promise.t<{
    "queue": string,
    "messageCount": int,
    "consumerCount": int,
  }> = "assertQueue"

  @send
  external bindQueue: (t, Queue.name, Exchange.name, string) => Js.Promise.t<unit> = "bindQueue"

  @send external prefetch: (t, int) => Js.Promise.t<unit> = "prefetch"

  @send
  external consume: (t, Queue.name, 'a => unit) => Js.Promise.t<unit> = "consume"
}

module ChannelWrapper = {
  type t
  type name = string
  type routingKey = string
  type ack = Queue.message => unit
  type nack = Queue.message => unit

  @send external ack: (t, Queue.message) => unit = "ack"
  @send external nack: (t, Queue.message) => unit = "nack"
  @send external queueLength: t => int = "queueLength"
  @send external close: t => unit = "close"
  @send
  external waitForConnect: t => Js.Promise.t<unit> = "waitForConnect"

  @send
  external on: (
    t,
    @string
    [
      | #connect(unit => unit)
      | #error((Js.Exn.t, Channel.name) => unit)
      | #close(unit => unit)
    ],
  ) => t = "on"

  @send
  external publish': (t, Exchange.name, routingKey, 'message, 'options) => Js.Promise.t<unit> =
    "publish"

  let publish = (t, e, k, m, o) =>
    publish'(t, e, k, m, o) |> {
      open Js.Promise
      then_(_ => resolve(m))
    }

  @send
  external sendToQueue': (t, Queue.name, 'message, 'options) => Js.Promise.t<unit> = "sendToQueue"

  let sendToQueue = (t, q, m, o) =>
    sendToQueue'(t, q, m, o) |> {
      open Js.Promise
      then_(_ => resolve(m))
    }
}

module AmqpConnectionManager = {
  type t
  module Options = {
    type t<'connectionOptions> = 'connectionOptions
  }

  @send external isConnected: t => bool = "isConnected"
  @send external close: t => unit = "close"
  @send
  external on: (
    t,
    @string
    [
      | #connect({"connection": t, "url": url} => unit)
      | #disconnect({"err": Js.Exn.t} => unit)
    ],
  ) => t = "on"

  @send
  external createChannel: (t, Channel.Config.t<'a>) => ChannelWrapper.t = "createChannel"
}

@module("amqp-connection-manager")
external connect: (
  urls,
  ~options: AmqpConnectionManager.Options.t<'a>=?,
  unit,
) => AmqpConnectionManager.t = "connect"
