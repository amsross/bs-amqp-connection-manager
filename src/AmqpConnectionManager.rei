type url = string;
type urls = array(url);

exception ConnectionError(Js.Exn.t);

module Queue: {
  type name = string;
  type message = {content: Node.Buffer.t};
};

module Exchange: {type name = string;};

module Channel: {
  type t;
  type name = string;
  type ack = Queue.message => unit;
  type nack = Queue.message => unit;

  let ack: t => ack;
  let nack: t => nack;

  module Config: {
    type nonrec t('a) = {.. "setup": t => Js.Promise.t(unit)} as 'a;
  };

  let assertExchange:
    (t, Exchange.name, string, Js.t('options)) => Js.Promise.t(Exchange.name);
  let assertQueue:
    (t, Queue.name, Js.t('options)) =>
    Js.Promise.t({
      .
      "queue": string,
      "messageCount": int,
      "consumerCount": int,
    });
  let bindQueue: (t, Queue.name, Exchange.name, string) => Js.Promise.t(unit);
  let prefetch: (t, int) => Js.Promise.t(unit);
  let consume: (t, Queue.name, Queue.message => unit) => Js.Promise.t(unit);
};

module ChannelWrapper: {
  type t;
  type name = string;
  type routingKey = string;
  type ack = Queue.message => unit;
  type nack = Queue.message => unit;

  let ack: t => ack;
  let nack: t => nack;
  let queueLength: t => int;
  let close: t => unit;
  let waitForConnect: t => Js.Promise.t(unit);

  let on:
    (
      t,
      [
        | `connect(unit => unit)
        | `error((Js.Exn.t, Channel.name) => unit)
        | `close(unit => unit)
      ]
    ) =>
    t;

  let publish:
    (t, Exchange.name, routingKey, Js.Json.t, Js.t('options)) =>
    Js.Promise.t(Js.Json.t);

  let sendToQueue:
    (t, Queue.name, Js.Json.t, Js.t('options)) => Js.Promise.t(Js.Json.t);
};

module AmqpConnectionManager: {
  type t;
  module Options: {type t('connectionOptions) = Js.t('connectionOptions);};

  /** Returns true if the AmqpConnectionManager is connected to a broker, false
   * otherwise. */
  let isConnected: t => bool;

  /** Close this AmqpConnectionManager and free all associated resources. */
  let close: t => unit;

  let on:
    (
      t,
      [
        | `connect(
            {
              .
              "connection": t,
              "url": url,
            } =>
            unit,
          )
        | `disconnect({. "err": Js.Exn.t} => unit)
      ]
    ) =>
    t;

  /** Create a new ChannelWrapper. This is a proxy for the actual channel (which
   * may or may not exist at any moment, depending on whether or not we are
   * currently connected.) */
  let createChannel: (t, Channel.Config.t('a)) => ChannelWrapper.t;
};

/** Creates a new AmqpConnectionManager, which will connect to one of the URLs
 * provided in `urls`. If a broker is unreachable or dies, then
 * AmqpConnectionManager will try the next available broker, round-robin. */
let connect:
  (urls, ~options: AmqpConnectionManager.Options.t('a)=?, unit) =>
  AmqpConnectionManager.t;
