#region Copyright & License
//
// Solace Messaging API
// Copyright 2009-2021 Solace Corporation. All rights reserved. //
//
// This software is proprietary software of Solace Corporation and intended only
// for use in conjunction with one or more Solace Message Routers.  By using this
// software, you are agreeing to the license terms and conditions located at
// https://solace.com/license-software.
//
//                              * DirectPubSub *
//
// This sample demonstrates:
//  - Subscribing to a Topic for Direct messages.
//  - Publishing direct messages to a Topic.
//  - Receiving messages with a message handler.
//
// This sample shows the basics of creating a context, creating a
// session, connecting a session, subscribing to a topic, and publishing
// direct messages to a Topic. This is meant to be a very basic example, 
// so it uses minimal session properties and a message handler that simply 
// prints any received message to the screen.
// 
// Although other samples make use of common code to perform some of the
// most common actions, this sample explicitly includes many of these common
// methods to emphasize the most basic building blocks of any application.
// 
#endregion

using System;
using System.Collections.Generic;
using System.Text;
using SolaceSystems.Solclient.Messaging;
using System.Threading;

namespace SolaceSystems.Solclient.Examples.Messaging.Samples
{
    class DirectPubSub : SampleApp
    {
        /// <summary>
        /// A short description.
        /// </summary>
        /// <returns></returns>
        public override string ShortDescription()
        {
            return "Direct Delivery Mode Publish and Subscribe";
        }

        /// <summary>
        /// Command line arguments options
        /// </summary>
        /// <param name="extraOptionsForCommonArgs"></param>
        /// <param name="sampleSpecificUsage"></param>
        /// <returns></returns>
        public override bool GetIsUsingCommonArgs(out string extraOptionsForCommonArgs, out string sampleSpecificUsage)
        {
            extraOptionsForCommonArgs = null;
            sampleSpecificUsage = null;
            return true;
        }


        /// <summary>
        /// The message handler is invoked for each direct message received
        /// by the Session. This sample simplly prints the message to the
        /// screen.
        /// 
        /// Message handler code is executed within the API thread, which means
        /// that it should deal with the message quickly or queue the message
        /// for further processing in another thread.
        /// 
        /// Note: In other samples, a common message handler is used. However,
        /// to emphasize this programming paradigm, this sample directly includes 
        /// the message receive handler.
        /// </summary> 
        /// <param name="source"></param>
        /// <param name="args"></param>
        public static void HandleMessageEvent(Object source, MessageEventArgs args)
        {
            IMessage message = args.Message;

            Console.WriteLine("Received message:");
            Console.WriteLine(message.Dump());

            // It is recommended to Dispose a received message to free up heap
            // memory explicitly.
            message.Dispose();
        }

        /// <summary>
        /// The main function in the sample.
        /// </summary>
        /// <param name="args"></param>
        public override void SampleCall(string[] args)
        {
            #region Parse Arguments

            ArgParser cmdLineParser = new ArgParser();
            if (!cmdLineParser.Parse(args))
            {
                PrintUsage(INVALID_ARGUMENTS_ERROR);
                return;
            }

            #endregion

            #region Initialize properties from command line

            ContextProperties contextProps = new ContextProperties();
            SessionProperties sessionProps = new SessionProperties();

            sessionProps.Host = cmdLineParser.Config.IpPort.ip;
            sessionProps.UserName = cmdLineParser.Config.RouterUserVpn.user;
            sessionProps.Password = cmdLineParser.Config.UserPassword;
            sessionProps.SSLValidateCertificate = false;

            if (cmdLineParser.Config.RouterUserVpn.vpn != null)
            {
                sessionProps.VPNName = cmdLineParser.Config.RouterUserVpn.vpn;
            }

            // With reapply subscriptions enabled, the API maintains a
            // cache of added subscriptions in memory. These subscriptions
            // are automatically reapplied following a channel reconnect. 
            sessionProps.ReconnectRetries = 3;
            sessionProps.ReapplySubscriptions = true;

            if (cmdLineParser.Config.Compression)
            {
                // Compression is set as a number from 0-9, where 0 means "disable
                // compression", and 9 means max compression. The default is no
                // compression.
                // Selecting a non-zero compression level auto-selects the
                // compressed SMF port on the appliance, as long as no SMF port is
                // explicitly specified.
                sessionProps.CompressionLevel = 9;
            }

            #endregion

            IContext context = null;
            ISession session = null;
            
            try
            {
                InitContext(cmdLineParser.LogLevel);
                #region Create the Context

                Console.WriteLine("Creating the context ...");
                context = ContextFactory.Instance.CreateContext(contextProps, null);

                #endregion

                #region Create and connect the Session

                Console.WriteLine("Creating the session ...");
                session = context.CreateSession(sessionProps, HandleMessageEvent, SampleUtils.HandleSessionEvent);

                Console.WriteLine("Connecting the session ...");
                if (session.Connect() == ReturnCode.SOLCLIENT_OK)
                {
                    Console.WriteLine("Session successfully connected");
                }

                #endregion

                #region Subscribe to the topic

                ITopic topic = ContextFactory.Instance.CreateTopic(SampleUtils.SAMPLE_TOPIC);
                Console.WriteLine("About to subscribe to topic" + topic.ToString());
                if (session.Subscribe(topic, true) == ReturnCode.SOLCLIENT_OK)
                {
                    Console.WriteLine("Successfully added topic subscription");
                }

                #endregion

                #region Publish the messages

                for (int msgsSent = 0; msgsSent < 10; msgsSent++)
                {
                    IMessage message = ContextFactory.Instance.CreateMessage();
                    message.Destination = topic;
                    message.DeliveryMode = MessageDeliveryMode.Direct;
                    message.BinaryAttachment = Encoding.ASCII.GetBytes(SampleUtils.MSG_ATTACHMENTTEXT);
                    session.Send(message);
                    message.Dispose();

                    // Wait 1 second between messages. This will also give time for the
                    // final message to be received.
                    Thread.Sleep(1000);
                }

                #endregion

                #region Unsubscribe from the topic

                if (session.Unsubscribe(topic, true) == ReturnCode.SOLCLIENT_OK)
                {
                    Console.WriteLine("Successfully removed topic subscription");
                }

                #endregion

            }
            catch (Exception ex)
            {
                PrintException(ex);
            }
            finally
            {
                if (session != null)
                {
                    session.Dispose();
                }
                if (context != null)
                {
                    context.Dispose();
                }
                // Must cleanup after. 
                CleanupContext();
            }
        }
    }
}
