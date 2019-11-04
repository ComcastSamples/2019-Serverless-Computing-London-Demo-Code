'use strict';
/* 
 * based on sqs-poller in AWS serverless App Repository:
 * https://github.com/awslabs/serverless-application-model/blob/master/examples/apps/sqs-poller/index.js
 */

const AWS = require('aws-sdk');
const SQS = new AWS.SQS({ apiVersion: '2012-11-05' });

// Your queue URL stored in the queueUrl environment variable
const QUEUE_URL = process.env.queueUrl;
const PROCESS_MESSAGE = 'process-message';
const TABLE = process.env.table;

function putItem(item) {
    // put an item into the DynamoDB environment variable specified table 

    // Create DynamoDB document client
    var docClient = new AWS.DynamoDB.DocumentClient({apiVersion: '2012-08-10'});

    var params = {
      TableName: TABLE,
      Item: item
    };

    docClient.put(params, function(err, data) {
      if (err) {
        console.log("Error", err);
      } else {
        console.log("Success", data);
      }
    });
}

function processMessage(message) {
    // do something with the message from the queue

    // process message
    console.log("Processing message: ", message.Body);
    JSON.parse(message.Body)["host-list"].forEach( function(host) {
        console.log("putting host into DynamoDB: ", host.fqdn);
        putItem({host: host.fqdn, status: "PROCESSING"});
    });

    // delete message
    const params = {
        QueueUrl: QUEUE_URL,
        ReceiptHandle: message.ReceiptHandle,
    };
    return new Promise((resolve, reject) => {
        SQS.deleteMessage(params, (err) => (err ? reject(err) : resolve()));
    })
}

function poll(functionName, callback) {

    const params = {
        QueueUrl: QUEUE_URL,
        MaxNumberOfMessages: 10,
        VisibilityTimeout: 10,
    };
    
    // batch request messages
    SQS.receiveMessage(params, (err, data) => {
        if (err) {
            console.log("in poll() with error ", JSON.stringify(err));
            return callback(err);
        }
        console.log("in poll() without error. data is ", JSON.stringify(data));
        console.log("functionName is ", functionName);
        if (data.Messages) {
            // for each message, reinvoke the function
            const promises = data.Messages.map(
                (message) => 
                  processMessage(message)
            );
            // complete when all invocations have been made
            Promise.all(promises).then(() => {
                const result = `Messages received: ${data.Messages.length}`;
                console.log(result);
                callback(null, result);
            });
        } else {
            console.log("no messages received.")
        }
    });
}

exports.handler = (event, context, callback) => {
    console.log("in handler");
    try {
        // invoked by schedule
        poll(context.functionName, callback);
    } catch (err) {
        callback(err);
    }
};

