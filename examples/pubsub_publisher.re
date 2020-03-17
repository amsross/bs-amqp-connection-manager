/* this is pretty much the same as the examples provided in
 * node-amqp-connection-manager
 * https://github.com/benbria/node-amqp-connection-manager/blob/master/examples/pubsub-publisher.js */

module Amqp = AmqpConnectionManager;
[@bs.val] external setTimeout: (unit => unit, int) => int = "setTimeout";

let exchange_name = "amqp-connection-manager-sample2-ex";

// Create a connetion manager
let connection = Amqp.connect([|"amqp://localhost"|], ());
Amqp.AmqpConnectionManager.on(
  connection,
  `connect(_ => Js.Console.info("Connected!")),
);
Amqp.AmqpConnectionManager.on(
  connection,
  `disconnect(err => Js.Console.error(err)),
);

// Create a channel wrapper
let channelWrapper =
  Amqp.AmqpConnectionManager.createChannel(
    connection,
    {
      "json": true,
      "setup": channel =>
        Amqp.Channel.assertExchange(
          channel,
          exchange_name,
          "topic",
          Js.Obj.empty(),
        )
        |> Js.Promise.then_(_ => Js.Promise.resolve()),
    },
  );

// Send messages until someone hits CTRL-C or something goes wrong...
let rec sendMessage = () => {
  Amqp.ChannelWrapper.publish(
    channelWrapper,
    exchange_name,
    "",
    {"time": Js.Date.now()},
    Js.Obj.empty(),
  )
  |> Js.Promise.then_(msg => {
       Js.Console.info("Message sent");
       Js.Promise.make((~resolve, ~reject as _) =>
         setTimeout(() => resolve(. msg), 1000) |> ignore
       );
     })
  |> Js.Promise.then_(_ => sendMessage())
  |> Js.Promise.catch(err => {
       Js.Console.error(err);
       Amqp.ChannelWrapper.close(channelWrapper);
       Amqp.AmqpConnectionManager.close(connection);

       Js.Promise.resolve();
     });
};

Js.Console.info("Sending messages...");
sendMessage();
