import React, { useState, useMemo } from 'react';
import { useQuery, useQueryClient } from 'react-query';
import { useNavigate } from 'react-router-dom';
import {
  Box,
  Typography,
  Button,
  TextField,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
  Grid,
  Card,
  CardContent,
  CircularProgress,
  Alert,
  Chip,
  IconButton,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  DialogContentText,
} from '@mui/material';
import {
  Add as AddIcon,
  Edit as EditIcon,
  Delete as DeleteIcon,
  Download as DownloadIcon,
  Search as SearchIcon,
  Refresh as RefreshIcon,
} from '@mui/icons-material';
import { DataGrid } from '@mui/x-data-grid';
import toast from 'react-hot-toast';
import proxyService from '../services/proxyService';
import { useAuth } from '../context/AuthContext';

const ProxyList = () => {
  const [filters, setFilters] = useState({
    search: '',
    status: '',
    protocol: '',
    page: 1,
    limit: 10,
  });
  const [deleteDialog, setDeleteDialog] = useState({
    open: false,
    proxyId: null,
    proxyAddress: '',
  });

  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const { isSuperAdmin } = useAuth();

  const { data, isLoading, error, refetch } = useQuery(
    ['proxies', filters],
    () => proxyService.getProxies(filters),
    {
      keepPreviousData: true,
    }
  );

  const handleFilterChange = (field, value) => {
    setFilters(prev => ({
      ...prev,
      [field]: value,
      page: 1, // Reset to first page when filtering
    }));
  };

  const handleClearFilters = () => {
    setFilters({
      search: '',
      status: '',
      protocol: '',
      page: 1,
      limit: 10,
    });
  };

  const handleExport = async () => {
    try {
      const blob = await proxyService.exportProxies(filters);
      proxyService.downloadExportedFile(blob, `proxies-export-${new Date().toISOString().split('T')[0]}.csv`);
      toast.success('Export completed successfully');
    } catch (error) {
      toast.error('Export failed');
    }
  };

  const handleDeleteClick = (proxy) => {
    setDeleteDialog({
      open: true,
      proxyId: proxy.id,
      proxyAddress: `${proxy.ipAddress}:${proxy.port}`,
    });
  };

  const handleDeleteConfirm = async () => {
    try {
      await proxyService.deleteProxy(deleteDialog.proxyId);
      queryClient.invalidateQueries(['proxies']);
      toast.success('Proxy deleted successfully');
      setDeleteDialog({ open: false, proxyId: null, proxyAddress: '' });
    } catch (error) {
      toast.error('Failed to delete proxy');
    }
  };

  const handleDeleteCancel = () => {
    setDeleteDialog({ open: false, proxyId: null, proxyAddress: '' });
  };

  const getStatusChip = (status) => {
    const colors = {
      Active: 'success',
      Inactive: 'warning',
      Banned: 'error',
    };
    return <Chip label={status} color={colors[status]} size="small" />;
  };

  const columns = [
    {
      field: 'fullAddress',
      headerName: 'Address',
      width: 180,
      valueGetter: (params) => `${params.row.ipAddress}:${params.row.port}`,
    },
    {
      field: 'protocol',
      headerName: 'Protocol',
      width: 100,
    },
    {
      field: 'location',
      headerName: 'Location',
      width: 150,
      valueGetter: (params) => params.row.location || 'N/A',
    },
    {
      field: 'speed',
      headerName: 'Speed (Mbps)',
      width: 120,
      type: 'number',
    },
    {
      field: 'status',
      headerName: 'Status',
      width: 100,
      renderCell: (params) => getStatusChip(params.value),
    },
    {
      field: 'departmentId',
      headerName: 'Department',
      width: 150,
      valueGetter: (params) => params.row.departmentId?.name || 'N/A',
    },
    {
      field: 'expirationDate',
      headerName: 'Expires',
      width: 120,
      valueGetter: (params) => {
        if (!params.row.expirationDate) return 'Never';
        return new Date(params.row.expirationDate).toLocaleDateString();
      },
    },
    {
      field: 'actions',
      headerName: 'Actions',
      width: 120,
      sortable: false,
      renderCell: (params) => (
        <Box>
          <IconButton
            size="small"
            onClick={() => navigate(`/proxies/edit/${params.row.id}`)}
            color="primary"
          >
            <EditIcon />
          </IconButton>
          <IconButton
            size="small"
            onClick={() => handleDeleteClick(params.row)}
            color="error"
          >
            <DeleteIcon />
          </IconButton>
        </Box>
      ),
    },
  ];

  const paginationModel = useMemo(() => ({
    page: filters.page - 1, // DataGrid uses 0-based indexing
    pageSize: filters.limit,
  }), [filters.page, filters.limit]);

  const handlePaginationChange = (newPaginationModel) => {
    setFilters(prev => ({
      ...prev,
      page: newPaginationModel.page + 1,
      limit: newPaginationModel.pageSize,
    }));
  };

  if (error) {
    return (
      <Alert severity="error">
        Error loading proxies: {error.message}
      </Alert>
    );
  }

  return (
    <Box>
      <Box display="flex" justifyContent="space-between" alignItems="center" mb={3}>
        <Typography variant="h4">
          Proxy Management
        </Typography>
        <Box display="flex" gap={2}>
          <Button
            variant="outlined"
            startIcon={<DownloadIcon />}
            onClick={handleExport}
          >
            Export
          </Button>
          <Button
            variant="outlined"
            startIcon={<RefreshIcon />}
            onClick={() => refetch()}
          >
            Refresh
          </Button>
          <Button
            variant="contained"
            startIcon={<AddIcon />}
            onClick={() => navigate('/proxies/create')}
          >
            Add Proxy
          </Button>
        </Box>
      </Box>

      {/* Filters */}
      <Card sx={{ mb: 3 }}>
        <CardContent>
          <Grid container spacing={3} alignItems="center">
            <Grid item xs={12} sm={6} md={3}>
              <TextField
                fullWidth
                label="Search"
                placeholder="IP, location, notes..."
                value={filters.search}
                onChange={(e) => handleFilterChange('search', e.target.value)}
                InputProps={{
                  startAdornment: <SearchIcon color="action" />,
                }}
              />
            </Grid>
            <Grid item xs={12} sm={6} md={2}>
              <FormControl fullWidth>
                <InputLabel>Status</InputLabel>
                <Select
                  value={filters.status}
                  label="Status"
                  onChange={(e) => handleFilterChange('status', e.target.value)}
                >
                  <MenuItem value="">All</MenuItem>
                  <MenuItem value="Active">Active</MenuItem>
                  <MenuItem value="Inactive">Inactive</MenuItem>
                  <MenuItem value="Banned">Banned</MenuItem>
                </Select>
              </FormControl>
            </Grid>
            <Grid item xs={12} sm={6} md={2}>
              <FormControl fullWidth>
                <InputLabel>Protocol</InputLabel>
                <Select
                  value={filters.protocol}
                  label="Protocol"
                  onChange={(e) => handleFilterChange('protocol', e.target.value)}
                >
                  <MenuItem value="">All</MenuItem>
                  <MenuItem value="HTTP">HTTP</MenuItem>
                  <MenuItem value="HTTPS">HTTPS</MenuItem>
                  <MenuItem value="SOCKS4">SOCKS4</MenuItem>
                  <MenuItem value="SOCKS5">SOCKS5</MenuItem>
                </Select>
              </FormControl>
            </Grid>
            <Grid item xs={12} sm={6} md={2}>
              <Button
                variant="outlined"
                onClick={handleClearFilters}
                fullWidth
              >
                Clear Filters
              </Button>
            </Grid>
          </Grid>
        </CardContent>
      </Card>

      {/* Data Grid */}
      <Card>
        <Box sx={{ height: 600, width: '100%' }}>
          <DataGrid
            rows={data?.proxies || []}
            columns={columns}
            loading={isLoading}
            paginationModel={paginationModel}
            onPaginationModelChange={handlePaginationChange}
            paginationMode="server"
            rowCount={data?.pagination?.totalItems || 0}
            pageSizeOptions={[5, 10, 25, 50]}
            disableRowSelectionOnClick
            sx={{
              '& .MuiDataGrid-row:hover': {
                backgroundColor: 'rgba(25, 118, 210, 0.04)',
              },
            }}
          />
        </Box>
      </Card>

      {/* Delete Confirmation Dialog */}
      <Dialog
        open={deleteDialog.open}
        onClose={handleDeleteCancel}
        aria-labelledby="delete-dialog-title"
        aria-describedby="delete-dialog-description"
      >
        <DialogTitle id="delete-dialog-title">
          Confirm Deletion
        </DialogTitle>
        <DialogContent>
          <DialogContentText id="delete-dialog-description">
            Are you sure you want to delete the proxy {deleteDialog.proxyAddress}?
            This action cannot be undone.
          </DialogContentText>
        </DialogContent>
        <DialogActions>
          <Button onClick={handleDeleteCancel}>Cancel</Button>
          <Button onClick={handleDeleteConfirm} color="error" autoFocus>
            Delete
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
};

export default ProxyList;