module.exports.main = async (event, callback) => {
    console.log("EVENT TEST", event);
    return {
        statusCode: 200,
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({
            message: "This worked",
        }),
    };
}