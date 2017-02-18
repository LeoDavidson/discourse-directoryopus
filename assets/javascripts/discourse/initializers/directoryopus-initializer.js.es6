import { withPluginApi } from 'discourse/lib/plugin-api';

function apiInitCallback(api)
{
	const siteSettings = api.container.lookup('site-settings:main');
	if (!siteSettings.directoryopus_enabled) {
		return; // Plugin has been disabled on the server, so make it do nothing on the client.
	}

	// Add a link to the account linking landing page into the top-right hamburger menu.
	// This is so we can tell new users an easy way to find it again after creating an account.
	// I worked out the names and attributes by looking at the source and then using a debugger
	// to check exactly what was being looked for when the menu opens. Not obvious or documented
	// but you start to get a feel for it.
	api.decorateWidget('hamburger-menu:generalLinks', dec => {
		return {
			route: 'linkopuslanding',
			className: 'link-opus-link',
			label: 'directoryopus.linkopus_hamburger_label'
		};
	});
}

export default {
	name: 'init-directoryopus',
	initialize() { withPluginApi('0.7', apiInitCallback); }
};
