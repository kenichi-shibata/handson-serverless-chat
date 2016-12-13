console.log('Loading function');

var doc = require('dynamodb-doc');
var dynamo = new doc.DynamoDB();

exports.handler = function(event, context) {
    console.log('Received event:', JSON.stringify(event, null, 2));
    
    // TODO: テーブル名を確認してください
    var tableName = "YYYYMMDD-serverless-handson";
    var item = {
        Track: event.track,
        Comment: event.comment,
        Name: event.name,
        Timestamp: Number(Math.floor(Date.now() / 1000))
    }
    var params = {
        TableName: tableName,
        Item: item
    };
    
    dynamo.putItem(params, context.done);
};