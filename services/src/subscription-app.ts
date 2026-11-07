import './css/index.css';
import { createApp } from 'vue';
import SubscriptionView from './views/SubscriptionView.vue';

const artwork = import.meta.glob('../public/images/subscription/*.svg', {
  eager: true, query: '?raw', import: 'default'
});
const icons = Object.fromEntries(Object.entries(artwork).map(([path, svg]) => [
  path.replace('../public', ''), 'data:image/svg+xml;charset=UTF-8,' + encodeURIComponent(String(svg))
]));
const app = createApp(SubscriptionView);
app.provide('subscriptionIcons', icons);
app.provide('relatedEnabled', document.documentElement.dataset.related === 'true');
app.mount('#app');
