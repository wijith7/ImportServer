import ballerina/http;
import ballerina/log;
import ballerina/io;
import ballerina/mime;
import ballerina/jms;

endpoint http:Client clientEndpoint {
    url: "https://localhost:9443",
    auth: {
        scheme: http:BASIC_AUTH,
        username: "admin",
        password: "admin"
    },
    Accept: "*/*",
    secureSocket: {
        trustStore: {
            path: "${ballerina.home}/bre/security/ballerinaTruststore.p12",
            password: "ballerina"
        }
    }
};
endpoint http:Listener listener {
    port: 9090
};

@http:ServiceConfig { basePath: "/importService", cors: {
    allowOrigins: ["http://localhost:3000"],
    allowCredentials: false,
    allowHeaders: ["CORELATION_ID"],
    exposeHeaders: ["X-CUSTOM-HEADER"],
    maxAge: 84900
}
}
service<http:Service> importService bind listener {

    @http:ResourceConfig {
        methods: ["GET"],
        path: "/APItrigger/{value}"
    }

    APItrigger(endpoint client, http:Request req, string value) {

        http:Response res = new;

        string[] filePaths = ["./Import/File/OrderAPI_1.0.0.zip", "./Import/File/InventoryAPI_1.0.0.zip",
        "./Import/File/ItemAPI_1.0.0.zip",
        "./Import/File/LoginAPI_1.0.0.zip", "./Import/File/RevokeAPI_1.0.0.zip"];
        foreach i in filePaths{

            mime:Entity xmlFilePart = new;
            xmlFilePart.setContentDisposition(getContentDispositionForFormData("file"));

            xmlFilePart.setFileAsEntityBody(i, contentType = "application/zip");

            mime:Entity[] bodyParts = [xmlFilePart];

            http:Request request = new;
            request.setBodyParts(bodyParts, contentType = mime:MULTIPART_FORM_DATA);

            var response = clientEndpoint->post("/api-import-export-2.5.0-v1/import-api", request);

            match response {
                http:Response resp => {
                    io:println("\nPOST request:");
                    io:println(resp.getPayloadAsString());
                }
                error err => {
                    log:printError(err.message, err = err);
                }
            }
        }
        client->respond(res) but {
            error e => log:printError(
                           "Error sending response", err = e)
        };
    }

    @http:ResourceConfig {
        methods: ["GET"],
        path: "/USERtrigger/{value}"
    }

    USERtrigger(endpoint client, http:Request req, string value) {

        http:Response res = new;
        string[] filePaths = ["./Import/File/BuyerUserAdd.xml", "./Import/File/SellerUserAdd.xml"
        ];
        foreach i in filePaths{


            http:Request request = new;
            request.setFileAsPayload(i, contentType = "text/xml");
            request.setHeader("soapAction", " urn:addUser");

            var response = clientEndpoint->post("/services/RemoteUserStoreManagerService", request);

            match response {
                http:Response resp => {
                    io:println("\nPOST request:");
                    io:println(resp.statusCode);
                }
                error err => {
                    log:printError(err.message, err = err);
                }
            }
        }
        client->respond(res) but {
            error e => log:printError(
                           "Error sending response", err = e)
        };
    }


    @http:ResourceConfig {
        methods: ["GET"],
        path: "/ROLEStrigger/{value}"
    }

    ROLEStrigger(endpoint client, http:Request req, string value) {
        http:Response res = new;
        string[] filePaths = ["./Import/File/SellerRolesAddPayload.xml", "./Import/File/BuyerRolesAddPayload.xml"
        ];
        foreach i in filePaths{


            http:Request request = new;
            request.setFileAsPayload(i, contentType = "text/xml");
            request.setHeader("soapAction", " urn:addRole");

            var response = clientEndpoint->post("/services/RemoteUserStoreManagerService", request);

            match response {
                http:Response resp => {
                    io:println("\nPOST request:");
                    io:println(resp.statusCode);
                }
                error err => {
                    log:printError(err.message, err = err);
                }
            }
        }
        client->respond(res) but {
            error e => log:printError(
                           "Error sending response", err = e)
        };
    }

}

//file path that order items are hard coded.
string filePath = "Import/sample.json";

//Order management is done using an in memory map.
map<json> ordersMap = initialGet();

documentation{
                By initialGet() function we initialy load json into ordersMap.
                we use this to load sample.json only one time
}

function initialGet() returns map<json> {

    map<json> initialOrdersMap;
    json? payload = readSampleJSON(filePath);
    json[] jsonArr = check <json[]>payload.orderArray;

    //put json objects in to map
    foreach id, jOrder in jsonArr {

        //converted in to string
        string a = jOrder.ID.toString();
        //change a
        initialOrdersMap[a] = jOrder;

    }
    return initialOrdersMap;
}

//close the character channel when done
function close(io:CharacterChannel characterChannel) {

    characterChannel.close() but {

        error e =>
        log:printError("Error occurred while closing character stream", err = e)

    };
}

//read the json that are hard coded.
function readSampleJSON(string path) returns json {

    io:ByteChannel byteChannel = io:openFile(path, io:READ);
    io:CharacterChannel ch = new io:CharacterChannel(byteChannel, "UTF8");

    match ch.readJson() {

        json result => {

            close(ch);
            return result;

        }

        error err => {

            close(ch);
            throw err;

        }
    }
}





// RESTful service.
@http:ServiceConfig { basePath: "/ordermgt" }

service<http:Service> orderMgt bind listener {

    // Resource that handles the HTTP GET requests that are directed to a specific place
    @http:ResourceConfig {
        methods: ["GET"],
        path: "/order/{orderId}"

    }

    findOrder(endpoint client, http:Request req, string orderId) {

        //paylode :this is the json that we store response
        json payload;
        json[] jsonArray;

        //send all the items
        if (orderId == "all"){

            payload = jsonArray;

        }

        // we can get object one by one
        foreach i, jsonObjectFromOrdersMap in ordersMap  {

            int a = check <int>i;
            jsonArray[a - 1] = jsonObjectFromOrdersMap;

        }

        http:Response response;

        if (payload == null) {

            payload = "Order : " + orderId + " cannot be found.";

        }

        // Set the JSON payload in the outgoing response message.
        response.setJsonPayload(untaint payload);
        // Send response to the client.
        client->respond(response) but {
            error e => log:printError("Error sending response", err = e)
        };

    }

    // Resource that handles the HTTP POST requests that are directed to the path
    // '/orders' to create a new Order.

    @http:ResourceConfig {

        methods: ["POST"],
        path: "/order"

    }

    addOrder(endpoint client, http:Request req) {

        json orderReq = check req.getJsonPayload();
        string orderId = orderReq.Order.ID.toString();
        ordersMap[orderId] = orderReq;
        // Create response message.
        json payload = { status: "Order Created.", orderId: orderId };
        http:Response response;
        response.setJsonPayload(untaint payload);
        // Set 201 Created status code in the response message.
        response.statusCode = 201;
        // Set 'Location' header in the response message.
        // This can be used by the client to locate the newly added order.
        //response.setHeader("Location", "http://localhost:9090/ordermgt/order/" +
        //        orderId);
        response.setHeader("Location", "http://localhost:9090/ordermgt/order/" +
                orderId);
        // Send response to the client.
        client->respond(response) but {
            error e => log:printError("Error sending response", err = e)
        };

    }

    // Resource that handles the HTTP PUT requests that are directed to the path
    // '/orders' to update an existing Order.

    @http:ResourceConfig {

        methods: ["PUT"],
        path: "/order/{orderId}"
    }

    updateOrder(endpoint client, http:Request req, string orderId) {

        json updatedOrder = check req.getJsonPayload();
        // Find the order that needs to be updated and retrieve it in JSON format.
        json existingOrder = ordersMap[orderId];
        // Updating existing order with the attributes of the updated order.

        if (existingOrder != null) {

            existingOrder.stock = updatedOrder.stock;
            ordersMap[orderId] = existingOrder;

        } else {

            existingOrder = "Order : " + orderId + " cannot be found.";

        }

        http:Response response;
        // Set the JSON payload to the outgoing response message to the client.
        response.setJsonPayload(untaint existingOrder);
        // Send response to the client.
        client->respond(response) but {
            error e => log:printError("Error sending response", err = e)
        };
    }
}





function getContentDispositionForFormData(string partName) returns mime:ContentDisposition {
    mime:ContentDisposition contentDisposition = new;
    contentDisposition.name = partName;
    contentDisposition.disposition = "form-data";
    return contentDisposition;
}
