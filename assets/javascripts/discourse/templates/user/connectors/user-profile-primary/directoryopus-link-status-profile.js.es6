export default {
	setupComponent(args, component) {

		// https://meta.discourse.org/t/important-changes-to-plugin-outlets-for-ember-2-10/54136
		// https://meta.discourse.org/t/testing-viewingself-from-plugin-outlet/57576

		// Similar to viewingSelf found in the parent, but that is inaccessible within our own plugin template.
		// I've given this an opus... prefix in case the real thing is ever propagated to plugin templates, to avoid conflicts.
		
		const currentUser = Discourse.User.current();
		const viewingSelf = !!(currentUser && (args.model.get("username") === currentUser.get("username")));
		const canLinkUser = viewingSelf || !!(currentUser && currentUser.get("admin"));
		
		component.set('opusViewingSelf', viewingSelf);
		component.set('opusCanLinkUser', canLinkUser);
	}
}
