import dopuslib from "discourse/plugins/discourse-directoryopus/lib/directoryopus-link-lib";

export default {
	setupComponent(args, component) {
		dopuslib.setupUserProfileComponent(args.model, component, false);
	}
}
