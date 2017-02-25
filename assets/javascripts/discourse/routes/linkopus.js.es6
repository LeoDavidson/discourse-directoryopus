export default Discourse.Route.extend({

	model() {
		return this.modelFor("user");
	},

	afterModel(userModel) {
		// If a normal user tries to view users/<username>/link-opus for another account,
		// send them to that account's summary page instead, as a convenience. This is not
		// for security as nothing on the javascript side can be relied on for security.
		// Since admins have can_edit for all users, they can see the linking page for anyone.
		if (!userModel.get("can_edit")) {
			this.replaceWith("user.summary");
		}
	},

	setupController(controller, userModel) {
		controller.set('model', userModel);
		if (typeof userModel !== "undefined") {
			controller.initPermissions();
			controller.startLinkQuery(); // Call the server to get the current state of the account.
		}
	},

	titleToken() {
 		return I18n.t("directoryopus.linkopus_title");
	},

	renderTemplate() {
		this.render("linkopus");
	},
});
