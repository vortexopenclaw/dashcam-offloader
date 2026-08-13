function assertTrustedSender(event, expectedURL) {
  if (!event?.senderFrame || event.senderFrame.url !== expectedURL) {
    throw new Error("This request did not come from the Dashcam Offloader window.");
  }
}

module.exports = { assertTrustedSender };
