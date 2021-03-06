type url = string
type urls = array<url>

exception ConnectionError(Js.Exn.t)

module Queue: {
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

module Exchange: {
  type name = string
}

module Channel: {
  type t
  type name = string
  type ack = Queue.message => unit
  type nack = Queue.message => unit

  let ack: t => ack
  let nack: t => nack

  module Config: {
    type t<'a> = {.."setup": t => Js.Promise.t<unit>} as 'a
  }

  let assertExchange: (t, Exchange.name, string, 'options) => Js.Promise.t<Exchange.name>
  let assertQueue: (
    t,
    Queue.name,
    'options,
  ) => Js.Promise.t<{
    "queue": string,
    "messageCount": int,
    "consumerCount": int,
  }>
  let bindQueue: (t, Queue.name, Exchange.name, string) => Js.Promise.t<unit>
  let prefetch: (t, int) => Js.Promise.t<unit>
  let consume: (t, Queue.name, Queue.message => unit) => Js.Promise.t<unit>
}

module ChannelWrapper: {
  type t
  type name = string
  type routingKey = string
  type ack = Queue.message => unit
  type nack = Queue.message => unit

  let ack: t => ack
  let nack: t => nack
  let queueLength: t => int
  let close: t => unit
  let waitForConnect: t => Js.Promise.t<unit>

  let on: (
    t,
    [
      | #connect(unit => unit)
      | #error((Js.Exn.t, Channel.name) => unit)
      | #close(unit => unit)
    ],
  ) => t

  let publish: (t, Exchange.name, routingKey, 'message, 'options) => Js.Promise.t<'message>

  let sendToQueue: (t, Queue.name, 'message, 'options) => Js.Promise.t<'message>
}

module AmqpConnectionManager: {
  type t
  module Options: {
    type t<'connectionOptions> = 'connectionOptions
  }

  @ocaml.doc(" Returns true if the AmqpConnectionManager is connected to a broker, false
   * otherwise. ")
  let isConnected: t => bool

  @ocaml.doc(" Close this AmqpConnectionManager and free all associated resources. ")
  let close: t => unit

  let on: (
    t,
    [
      | #connect({"connection": t, "url": url} => unit)
      | #disconnect({"err": Js.Exn.t} => unit)
    ],
  ) => t

  @ocaml.doc(" Create a new ChannelWrapper. This is a proxy for the actual channel (which
   * may or may not exist at any moment, depending on whether or not we are
   * currently connected.) ")
  let createChannel: (t, Channel.Config.t<'a>) => ChannelWrapper.t
}

@ocaml.doc(" Creates a new AmqpConnectionManager, which will connect to one of the URLs
 * provided in `urls`. If a broker is unreachable or dies, then
 * AmqpConnectionManager will try the next available broker, round-robin. ")
let connect: (
  urls,
  ~options: AmqpConnectionManager.Options.t<'a>=?,
  unit,
) => AmqpConnectionManager.t
