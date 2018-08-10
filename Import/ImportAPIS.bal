import ballerina / http;
import ballerina / io;
import ballerina / log;
import ballerina / mime;

endpoint http:Client clientEndpoint {
    url: "https://localhost:9443/api-import-export-2.5.0-v1",
    auth: {
        scheme: http:BASIC_AUTH,
        username: "admin",
        password: "admin"
    },
    secureSocket: {
        trustStore: {
            path: "${ballerina.home}/bre/security/ballerinaTruststore.p12",
            password: "ballerina"
        }
    }
};


function main(string... args) {



    string [] filePaths = ["./File/OrderAPI_1.0.0.zip", "./File/InventoryAPI_1.0.0.zip", "./File/ItemAPI_1.0.0.zip", "./File/LoginAPI_1.0.0.zip", "./File/RevokeAPI_1.0.0.zip"];
    foreach i in filePaths{




        mime:Entity xmlFilePart = new;
        xmlFilePart.setContentDisposition(getContentDispositionForFormData("file"));


        xmlFilePart.setFileAsEntityBody(i, contentType = "application/zip");


        mime:Entity[] bodyParts = [xmlFilePart];

        http:Request request = new;
        request.setBodyParts(bodyParts, contentType = mime:MULTIPART_FORM_DATA);

        var response = clientEndpoint->post("/import-api", request);

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
}

function getContentDispositionForFormData(string partName) returns mime:ContentDisposition {
    mime:ContentDisposition contentDisposition = new;
    contentDisposition.name = partName;
    contentDisposition.disposition = "form-data";
    return contentDisposition;
}
