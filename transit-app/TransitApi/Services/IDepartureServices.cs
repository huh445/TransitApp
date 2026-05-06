namespace TransitApi.Services;

public interface IDeparturesService
{
    Task<List<object>> GetDeparturesForDeviceAsync(string deviceId);
    Task<object?> GetDeparturesForStationAsync(string stationId); 
}