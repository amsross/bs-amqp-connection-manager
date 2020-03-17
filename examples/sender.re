/* this is pretty much the same as the examples provided in
 * node-amqp-connection-manager
 * https://github.com/benbria/node-amqp-connection-manager/blob/master/examples/sender.js
 * */

module Amqp = AmqpConnectionManager;
[@bs.val] external setTimeout: (unit => unit, int) => int = "setTimeout";

let queue_name = "amqp-connection-manager-sample1";

// Create a connetion manager
let connection = Amqp.connect([|"amqp://localhost"|], ());

Amqp.AmqpConnectionManager.on(
  connection,
  `disconnect(err => Js.Console.error(err)),
)
|> ignore;

Amqp.AmqpConnectionManager.on(
  connection,
  `connect(_ => Js.Console.info("connected!")),
)
|> ignore;

// Set up a channel listening for messages in the queue.
let channelWrapper =
  Amqp.AmqpConnectionManager.createChannel(
    connection,
    {
      "json": true,
      "setup": channel =>
        // `channel` here is a regular amqplib `ConfirmChannel`.
        Js.Promise.(
          all([|
            Amqp.Channel.assertQueue(channel, queue_name, {"durable": true})
            |> then_(_ => resolve()),
          |])
          |> then_(_ => resolve())
        ),
    },
  );

// Send messages until someone hits CTRL-C or something goes wrong...
let rec sendMessage = () => {
  Amqp.ChannelWrapper.sendToQueue(
    channelWrapper,
    queue_name,
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
