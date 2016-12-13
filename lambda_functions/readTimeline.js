console.log('Loading function');
 
var doc = require('dynamodb-doc');
var docClient = new doc.DynamoDB();
 
exports.handler = function(event, context) {
    console.log('Received event:', JSON.stringify(event, null, 2));
    
    var params = {};
    
    // TODO: テーブル名を確認してください
    params.TableName = "YYYYMMDD-serverless-handson";

    params.KeyConditions = [docClient.Condition("Track", "EQ", event.track),
                            docClient.Condition("Timestamp", "GT", 2000)];

    params.Limit = 40;
    params.ScanIndexForward = false;

    console.log(params);
    docClient.query(params, context.done);
};