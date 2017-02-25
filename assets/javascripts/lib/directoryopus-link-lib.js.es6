export default {
	setupUserProfileComponent(userModel, component, small) {

		// https://meta.discourse.org/t/important-changes-to-plugin-outlets-for-ember-2-10/54136
		// https://meta.discourse.org/t/testing-viewingself-from-plugin-outlet/57576

		const currentUser  = Discourse.User.current();
		const currentAdmin = !!(currentUser && currentUser.get("admin"));
	//	const viewingAdmin = !!(userModel.get("admin"));
		const viewingStaff = !!(userModel.get("staff"));
		const viewingSelf  = !!(currentUser && (userModel.get("username") === currentUser.get("username")));
		const canLinkUser  = viewingSelf || currentAdmin;
		
	//	component.set("opusViewingSelf", viewingSelf);
		component.set("opusCanLinkUser", canLinkUser);

		var version = userModel.custom_fields && userModel.custom_fields["directoryopus_link_version"];
		var edition = userModel.custom_fields && userModel.custom_fields["directoryopus_link_edition"];

		var opusLinkClass = null;
		var opusLinkIcon  = null;
		var opusLinkText  = null;

		if (version || edition) {
			if (typeof version !== "string" || !/^\w+$/.test(version)) {
				version = ""; // If the version isn't alphanumeric, blank it out, in case something bogus has been fed into our system. Prevents outputing it to all our users.
			}
			if (typeof edition !== "string") {
				edition = ""; // Ensure it's safe to call toLowerCase.
			}
			edition = edition.toLowerCase();
			var isPro = (edition === "pro");
			var isLight = (!isPro && edition === "light");

			opusLinkClass = "directoryopus-link-userpage" + (isPro?"-pro":isLight?"-light":"");
			opusLinkIcon = "star";
			opusLinkText = (small?"":"Registered ") + "Directory Opus " + version + (isPro?" Pro":isLight?" Light":"") + (small?"":" user");
		}
		else if (!viewingStaff) {
			opusLinkClass = "directoryopus-link-userpage-pleaselink";
			opusLinkIcon = "chain-broken";
			opusLinkText = "Not linked" + (small?"":" to a Directory Opus version or registration");
		}

		component.set("opusLinkClass", opusLinkClass);
		component.set("opusLinkIcon", opusLinkIcon);
		component.set("opusLinkText", opusLinkText);

		component.set("opusLinkAnything", !!(canLinkUser || opusLinkClass));
	}
}
