import api from './api';

class ProxyService {
  async getProxies(params = {}) {
    const response = await api.get('/proxies', { params });
    return response.data.data;
  }

  async getProxyById(id) {
    const response = await api.get(`/proxies/${id}`);
    return response.data.data.proxy;
  }

  async createProxy(proxyData) {
    const response = await api.post('/proxies', proxyData);
    return response.data.data.proxy;
  }

  async updateProxy(id, proxyData) {
    const response = await api.put(`/proxies/${id}`, proxyData);
    return response.data.data.proxy;
  }

  async deleteProxy(id) {
    const response = await api.delete(`/proxies/${id}`);
    return response.data;
  }

  async getProxyStats() {
    const response = await api.get('/proxies/stats');
    return response.data.data;
  }

  async exportProxies(params = {}) {
    const response = await api.get('/proxies/export', {
      params,
      responseType: 'blob',
    });
    return response.data;
  }

  // Helper method to download exported file
  downloadExportedFile(blob, filename = 'proxies-export.csv') {
    const url = window.URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.setAttribute('download', filename);
    document.body.appendChild(link);
    link.click();
    link.remove();
    window.URL.revokeObjectURL(url);
  }
}

export default new ProxyService();