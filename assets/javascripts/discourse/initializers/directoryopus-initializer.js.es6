import { withPluginApi } from 'discourse/lib/plugin-api';
import { ajax } from 'discourse/lib/ajax';
import { popupAjaxError } from 'discourse/lib/ajax-error';

function apiInitCallback(api)
{
	const siteSettings = api.container.lookup('site-settings:main');
	if (!siteSettings.directoryopus_enabled) {
		return; // Plugin has been disabled on the server, so make it do nothing on the client.
	}

	// Plugin can only be used by logged-in users. If anon user, make it do nothing on the client.
	// Effects of the plugin changing people's groups will still be seen by anon users, since that
	// is a side effect of that user using the plugin to link their account, not something that
	// every other user requires the plugin to see the result of.
	const currentUser = api.getCurrentUser();
	if (!currentUser) {
		return;
	}
}

export default {
	name: 'init-directoryopus',
	initialize() { withPluginApi('0.7', apiInitCallback); }
};
