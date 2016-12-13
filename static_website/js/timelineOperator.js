var config = {
    apiGatewayRegion: 'ap-northeast-1',    
};

define(function () {

    var getClient = function (credentials) {
        return apigClientFactory.newClient({
            accessKey: credentials.accessKeyId,
            secretKey: credentials.secretAccessKey,
            sessionToken: credentials.sessionToken,
            region: config.apiGatewayRegion
        });
    };

    return {
        loadAndAppend: function (credentials, track, onSuccess) {
            var apigClient = getClient(credentials);
            apigClient.commentsGet({
                track: track
            }, {}, {}
                ).then(function (result) {
                    onSuccess(result.data.Items);
                }).catch(function (result) {
                    console.log(result);
                });
        },
        postComment: function (credentials, track, name, comment, onSuccess) {
            var apigClient = getClient(credentials);
            apigClient.commentsPost({}, {
                track: track,
                name: name,
                comment: comment
            }, {}).then(function (result) {
                onSuccess();
            }).catch(function (result) {
                console.log(result);
            });
        }
    };
});

