import { defineConfig } from 'vitepress';
import { version } from '../../package.json';

export default defineConfig({
	lang: 'en-US',
	title: 'Lokahostcp Control Panel',
	description: 'Open-source web server control panel.',

	lastUpdated: true,
	cleanUrls: false,

	head: [
		['link', { rel: 'icon', type: 'image/svg+xml', href: '/logo.svg' }],
		['link', { rel: 'icon', type: 'image/png', sizes: '48x48', href: '/favicon-48.png' }],
		['link', { rel: 'apple-touch-icon', sizes: '180x180', href: '/apple-touch-icon.png' }],
		['link', { rel: 'manifest', href: '/site.webmanifest' }],
		['meta', { name: 'theme-color', content: '#b7236a' }],
	],

	themeConfig: {
		logo: '/logo.svg',

		nav: nav(),

		// The Twitter and Facebook handles here were produced by renaming the
		// upstream project's accounts, so they never pointed at this project.
		// Re-add them once accounts actually exist.
		socialLinks: [{ icon: 'github', link: 'https://github.com/lokahostcp/lokahostcp' }],

		sidebar: { '/docs/': sidebarDocs() },

		outline: [2, 3],

		editLink: {
			pattern: 'https://github.com/lokahostcp/lokahostcp/edit/main/docs/:path',
			text: 'Edit this page on GitHub',
		},

		footer: {
			message: 'Released under the GPLv3 License.',
			// 2024 is when this project was forked. The previous 2019 dated the
			// upstream project, not this one.
			copyright: 'Copyright © 2024-present Lokahostcp Control Panel',
		},

		// Local search until this project has its own DocSearch index.
		//
		// The previous config carried the upstream project's Algolia appId and
		// apiKey, which the rename left untouched. Queries would have gone to
		// their index, on their account, and returned their documentation.
		search: {
			provider: 'local',
		},
	},
});

/** @returns {import("vitepress").DefaultTheme.NavItem[]} */
function nav() {
	return [
		{ text: 'Features', link: '/features' },
		{ text: 'Install', link: '/install' },
		{ text: 'Documentation', link: '/docs/introduction/getting-started', activeMatch: '/docs/' },
		// Removed, each verified dead or inherited rather than assumed:
		//   Team/Donate  - listed the upstream project's developers and its
		//                  donation accounts.
		//   Forum        - forum.lokahost.online does not resolve.
		// Re-add each once this project has its own.
		{
			text: `v${version}`,
			items: [
				{
					text: 'Changelog',
					link: 'https://github.com/lokahostcp/lokahostcp/blob/main/CHANGELOG.md',
				},
				{
					text: 'Contributing',
					link: 'https://github.com/lokahostcp/lokahostcp/blob/main/CONTRIBUTING.md',
				},
				{
					text: 'Security policy',
					link: 'https://github.com/lokahostcp/lokahostcp/blob/main/SECURITY.md',
				},
			],
		},
	];
}
/** @returns {import("vitepress").DefaultTheme.SidebarItem[]} */
function sidebarDocs() {
	return [
		{
			text: 'Introduction',
			collapsed: false,
			items: [
				{ text: 'Getting started', link: '/docs/introduction/getting-started' },
				{ text: 'Best practices', link: '/docs/introduction/best-practices' },
			],
		},
		{
			text: 'User guide',
			collapsed: false,
			items: [
				{ text: 'Account', link: '/docs/user-guide/account' },
				{ text: 'Backups', link: '/docs/user-guide/backups' },
				{ text: 'Cron jobs', link: '/docs/user-guide/cron-jobs' },
				{ text: 'Databases', link: '/docs/user-guide/databases' },
				{ text: 'DNS', link: '/docs/user-guide/dns' },
				{ text: 'File manager', link: '/docs/user-guide/file-manager' },
				{ text: 'Mail domains', link: '/docs/user-guide/mail-domains' },
				{ text: 'Notifications', link: '/docs/user-guide/notifications' },
				{ text: 'Packages', link: '/docs/user-guide/packages' },
				{ text: 'Statistics', link: '/docs/user-guide/statistics' },
				{ text: 'Users', link: '/docs/user-guide/users' },
				{ text: 'Web domains', link: '/docs/user-guide/web-domains' },
			],
		},
		{
			text: 'Server administration',
			collapsed: false,
			items: [
				{ text: 'Backup & restore', link: '/docs/server-administration/backup-restore' },
				{ text: 'Configuration', link: '/docs/server-administration/configuration' },
				{ text: 'Customisation', link: '/docs/server-administration/customisation' },
				{ text: 'Databases & phpMyAdmin', link: '/docs/server-administration/databases' },
				{ text: 'DNS clusters & DNSSEC', link: '/docs/server-administration/dns' },
				{ text: 'Email', link: '/docs/server-administration/email' },
				{ text: 'File manager', link: '/docs/server-administration/file-manager' },
				{ text: 'Firewall', link: '/docs/server-administration/firewall' },
				{ text: 'OS upgrades', link: '/docs/server-administration/os-upgrades' },
				{ text: 'Rest API', link: '/docs/server-administration/rest-api' },
				{ text: 'SSL certificates', link: '/docs/server-administration/ssl-certificates' },
				{ text: 'Web templates & caching', link: '/docs/server-administration/web-templates' },
				{ text: 'Troubleshooting', link: '/docs/server-administration/troubleshooting' },
			],
		},
		{
			text: 'Contributing',
			collapsed: false,
			items: [
				{ text: 'Building Packages', link: '/docs/contributing/building' },
				{ text: 'Development', link: '/docs/contributing/development' },
				{ text: 'Documentation', link: '/docs/contributing/documentation' },
				{ text: 'Quick install app', link: '/docs/contributing/quick-install-app' },
				{ text: 'Testing', link: '/docs/contributing/testing' },
				{ text: 'Translations', link: '/docs/contributing/translations' },
			],
		},
		{
			text: 'Community',
			collapsed: false,
			items: [
				{ text: 'Lokahostcp Nginx Cache', link: '/docs/community/lokahostcp-nginx-cache' },
				{
					text: 'Ioncube installer for Lokahostcp',
					link: '/docs/community/ioncube-lokahostcp-installer',
				},
				{ text: 'Install script generator', link: '/docs/community/install-script-generator' },
			],
		},
		{
			text: 'Reference',
			collapsed: false,
			items: [
				{ text: 'API', link: '/docs/reference/api' },
				{ text: 'CLI', link: '/docs/reference/cli' },
			],
		},
	];
}
