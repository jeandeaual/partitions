(function (document) {
    var metas = document.getElementsByTagName('meta');
    var changeViewportContent = function (content) {
        for (var i = 0; i < metas.length; i++) {
            if (metas[i].name == "viewport") {
                metas[i].content = content;
            }
        }
    };
    var initialize = function () {
        changeViewportContent("width=device-width, minimum-scale=1.0, maximum-scale=1.0");
    };
    var gestureStart = function () {
        changeViewportContent("width=device-width, minimum-scale=0.25, maximum-scale=1.6");
    };
    var gestureEnd = function () {
        initialize();
    };

    if (navigator.userAgent.match(/iPhone/i)) {
        initialize();

        document.addEventListener("touchstart", gestureStart, false);
        document.addEventListener("touchend", gestureEnd, false);
    }
})(document);
