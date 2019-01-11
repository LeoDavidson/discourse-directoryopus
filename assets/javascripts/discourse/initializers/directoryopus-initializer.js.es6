import { withPluginApi } from 'discourse/lib/plugin-api';

// For poster icons to work, you must go to the site's admin settings and paste this into the search field:
// - public_user_custom_fields
// Then add these two custom fields to the list, so they are exposed to the client side and made public:
// - directoryopus_link_edition
// - directoryopus_link_version
// Do not add any of the plugin's other fields. They may not all be public information, and the plugin has its
// own route JSON API for obtaining the extra details when asked by either an admin or the user looking at their
// own account. (FWIW there is an API for whitelisting more fields for admins only, but it's not useful to us.
// That API is whitelist_staff_user_custom_field which plugins can call on the Ruby side, but there's no API
// for plugins to add to the public whitelist; it should be done by an admin manually editing the site settings.)

function posterIconCallback(cfs, attrs) {
	if (attrs.staff) {
		return; // Our staff users have titles via groups that we don't want to mess with.
	}
	var version = cfs.directoryopus_link_version;
	var edition = cfs.directoryopus_link_edition;
	if (version || edition) {
		if ((new Date() - new Date(attrs.created_at)) > (1000*60*60*24*180)) {
			version = ""; // Post is older than 180 days (~6 months); leave the user's *current* version number off as it can be misleading on old posts.
		} else if (typeof version !== "string" || !/^\w+$/.test(version)) {
			version = ""; // If the version isn't alphanumeric, blank it out, in case something bogus has been fed into our system. Prevents outputing it to all our users.
		}
		if (typeof edition !== "string") {
			edition = ""; // Ensure it's safe to call toLowerCase.
		}
		edition = edition.toLowerCase();
		var isPro = (edition === "pro");
		var isLight = (!isPro && edition === "light");
		return {
			icon: "star",
			emoji: isLight ? "star" : "star2",
			className: "directoryopus-link-poster" + (isPro?"-pro":isLight?"-light":""),
			text: attrs.mobileView ? (" " + version + (isPro?"P":isLight?"L":"")) : (" Opus " + version + (isPro?" Pro":isLight?" Light":"")),
			title: (attrs.yours ? "Account Linking" : "Linked Account: Registered Directory Opus user"),
			url: (attrs.yours ? "/link-opus" : null)
		};
	}

	if (!attrs.mobileView) {
		if (attrs.yours) {
			return {
				icon: "link",
				emoji: "link",
				className: "directoryopus-link-poster-pleaselink",
				text: " CLICK HERE: Link your account for priority support",
				title: "Account Linking",
				url: "/link-opus"
			};
		}
		else {
			return {
				icon: "chain-broken",
				className: "directoryopus-link-poster-pleaselink",
				title: "Not linked to a Directory Opus version or registration"
			};
		}
	}
}

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
	// Turns out it's mentioned and confirmed here, too: https://meta.discourse.org/t/a-tour-of-how-the-widget-virtual-dom-code-in-discourse-works/40347/33
	api.decorateWidget('hamburger-menu:generalLinks', dec => {
		return {
			route: 'linkopuslanding',
			className: 'link-opus-link',
			label: 'directoryopus.linkopus_title'
		};
	});

	// Icons next to linked users
	api.addPosterIcon(posterIconCallback);
}

export default {
	name: 'init-directoryopus',
	initialize() { withPluginApi('0.7', apiInitCallback); }
};
