var lastLoadedItem = {
    entity: {},
    store: function (object) {
        this.entity = {
            name: object.Name,
            comment: object.Comment,
            timestamp: object.Timestamp,
            track: object.Track
        };

    },
    equals: function (other) {
        return (
            this.entity.name === other.Name &&
            this.entity.comment === other.Comment &&
            this.entity.track === other.Track &&
            this.entity.timestamp === other.Timestamp
            );
    }
};

var onItemLoaded = function (loadedItems) {
    if (loadedItems.length == 0) {
        return;
    }

    var lastItem = loadedItems[0];
    if (lastLoadedItem.equals(lastItem)) {
        return;
    }

    clear();

    $.each(loadedItems.reverse(), function () {
        $('tbody').prepend(
            $('<tr>').append(
                $('<td>').text(this.Name)
                ).append(
                    $('<td>').text(this.Comment)
                    ).append(
                        $('<td>').text(moment.unix(this.Timestamp).format("YYYY/MM/DD HH:mm:ss(ddd)"))
                        ));
    });
    lastLoadedItem.store(lastItem);
};

var clear = function () {
    lastLoadedItem.entity = {};
    $("tbody").empty();
};

// initialize AWS Credentials with Cognito Identity
(function () {
    require(['cognitoOperator'], function (cognito) {
        cognito.identity.withCredentials(function (credentials) {
            cognito.sync.read('name', function (value) {
                $("#name").val(value);
            });
            cognito.sync.read('track', function (value) {
                if (typeof value === "undefined") {
                    value = "basic";
                }
                $("#track option[value=none]").remove();
                $("#track").val(value);
                $("#track").prop("disabled", false);

                require(['timelineOperator'], function (timeline) {
                    timeline.loadAndAppend(credentials, value, onItemLoaded);
                });
            });
        });
    });
})();

$(function () {
    require(['cognitoOperator'], function (cognito) {
        cognito.identity.withCredentials(function (credentials) {
            // submit comment
            $('form').submit(function (event) {
                event.preventDefault();

                var f = $(this);
                var inputData = {
                    track: $("#track").val(),
                    name: $("#name").val(),
                    comment: $("#comment").val()
                };

                require(['timelineOperator'], function (timeline) {
                    timeline.postComment(credentials, $('#track').val(), $('#name').val(), $('#comment').val(), function () {
                        clear();
                        timeline.loadAndAppend(credentials, $('#track').val(), function (loadedItems) {
                            $("#comment").val("");
                            onItemLoaded(loadedItems);
                        });
                        require(['cognitoOperator'], function (cognito) {
                            cognito.sync.store('track', $("#track").val());
                            cognito.sync.store('name', $("#name").val());
                            cognito.sync.synchronize();
                        });
                    });
                });
            });

            // change track
            $('#track').change(function (event) {
                require(['cognitoOperator'], function (cognito) {
                    cognito.sync.store('track', $("#track").val());
                    cognito.sync.synchronize();

                    require(['timelineOperator'], function (timeline) {
                        clear();
                        timeline.loadAndAppend(credentials, $('#track').val(), onItemLoaded);
                    });
                });
            });
    
            // polling
            $(function () {
                setTimeout(function () {
                    require(['timelineOperator'], function (timeline) {
                        setInterval(function () {
                            timeline.loadAndAppend(credentials, $('#track').val(), onItemLoaded);
                        }, 4000);
                    });
                }, 10000);
            });
        });
    });
});