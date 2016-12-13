var config = {
    cognitoRegion: 'ap-northeast-1',
    // TODO: Cognito IdentityPool ID
    cognitoPoolId: 'ap-northeast-1:33b3b923-963d-4bc9-aac7-a56b8b9b4695',
};

define(function () {

    AWS.config.region = config.cognitoRegion;
    AWS.config.credentials = new AWS.CognitoIdentityCredentials({
        IdentityPoolId: config.cognitoPoolId,
    });

    var initialized = false;
    var cognitoSyncDataSetName = 'handsonDemoSet';
    var basicFunction = function (callback) {
        AWS.config.credentials.get(function () {
            var syncClient = new AWS.CognitoSyncManager();
            syncClient.openOrCreateDataset(cognitoSyncDataSetName, callback);
        });
    };


    return {

        identity: {
            withCredentials: function (onSuccess) {
                AWS.config.credentials.get(function (err) {
                    if (err) {
                        console.log(err);
                        return;
                    }
                    if (!initialized) {
                        console.log("Cognito Auth Successeed!");
                        console.log("Identity Id:" + AWS.config.credentials.identityId);
                        console.log("You can confirm at "
                            + "https://" 
                            + config.cognitoRegion
                            + ".console.aws.amazon.com/cognito/identities/?region=ap-northeast-1&pool="
                            + config.cognitoPoolId);
                        initialized = true;
                    }
                    onSuccess(AWS.config.credentials);
                });
            }
        },

        sync: {
            store: function (key, value) {
                basicFunction(function (error, dataset) {
                    dataset.put(key, value, function (err, record) { });
                });
            },

            synchronize: function () {
                basicFunction(function (error, dataset) {
                    dataset.synchronize({
                        onSuccess: function(dataset, newRecords) {
                            console.log('Synchronized!');
                        },
                        onConflict: function (dataset, conflicts, callback) {
                            var resolved = [];
                            for (var i = 0; i < conflicts.length; i++) {
                                resolved.push(conflicts[i].resolveWithLocalRecord());
                            }

                            dataset.resolve(resolved, function () {
                                return callback(true);
                            });
                        },
                        onFailure: function (error) {
                            console.log(error);
                        }
                    });
                });
            },

            read: function (key, onSuccess) {
                basicFunction(function (error, dataset) {
                    dataset.get(key, function (err, value) {
                        onSuccess(value);
                    });
                });
            }
        },


    };
});

