namespace TransitApi.Services;

public interface IDeparturesService
{
    // We define the input (deviceId) and the output (your list of station departures)
    Task<List<object>> GetDeparturesForDeviceAsync(string deviceId);
}