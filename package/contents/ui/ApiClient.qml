import QtQuick

import "../code/deye.mjs" as Deye

/** Sends a request built by code/deye.mjs and hands over its answer as readHttpResponse() reads it. */
QtObject {
    /** `token` is empty for the request that asks for one. */
    function post(request: var, token: string, receive: var): void {
        const call = new XMLHttpRequest();

        call.onreadystatechange = () => {
            if (call.readyState === XMLHttpRequest.DONE) {
                receive(Deye.readHttpResponse(call.status, call.responseText));
            }
        };

        call.open("POST", request.url);
        call.setRequestHeader("Content-Type", "application/json");

        if (token !== "") {
            call.setRequestHeader("Authorization", Deye.authorization(token));
        }

        call.send(JSON.stringify(request.body));
    }
}
