using Dicom;
using Dicom.Network;
using DicomClient = Dicom.Network.Client.DicomClient;
using System;
using System.Collections.Generic;
using System.Management.Automation;

namespace FoDicomCmdlets
{
  [Cmdlet("Move", "StudyByStudyInstanceUIDSync")]
  public class MoveStudyByStudyInstanceUIDCmdlet : Cmdlet
  {
    [Parameter(Mandatory = true)]
    public string StudyInstanceUID { get; set; }

    [Parameter(Mandatory = true)]
    public string DestinationAE { get; set; }

    [Parameter(Mandatory = true)]
    public string ServerHost { get; set; }

    [Parameter(Mandatory = true)]
    public int ServerPort { get; set; }

    [Parameter(Mandatory = true)]
    public string MyAE { get; set; }

    [Parameter(Mandatory = true)]
    public string ServerAE { get; set; }

    protected override void ProcessRecord()
    {
      var request = new DicomCMoveRequest(DestinationAE, StudyInstanceUID);
      var client = new DicomClient(ServerHost, ServerPort, false, MyAE, ServerAE);

      var responses = new List<DicomCMoveResponse>();

      request.OnResponseReceived += (req, response) =>
      {
        responses.Add(response);
      };
      
      client.AddRequestAsync(request).GetAwaiter().GetResult();
      client.SendAsync().GetAwaiter().GetResult();

      WriteObject(responses);
    }
  }

  [Cmdlet("Get", "StudiesByPatientNameAndBirthDate")]
  public class GetStudiesByPatientNameAndBirtdate : Cmdlet
  {
    [Parameter(Mandatory = true)]
    public string MyAE { get; set; }

    [Parameter(Mandatory = true)]
    public string QrServerAE { get; set; }

    [Parameter(Mandatory = true)]
    public string QrServerHost { get; set; }

    [Parameter(Mandatory = true)]
    public int QrServerPort { get; set; }

    [Parameter(Mandatory = true)]
    string PatientName { get; set; }
    
    [Parameter(Mandatory = true)]
    string PatientBirthDate { get; set; }
    
    [Parameter(Mandatory = true)]
    string Modality { get; set; }
    
    [Parameter(Mandatory = true)]
    int MonthsBack { get; set; }
    
    protected override void ProcessRecord()
    {
      if (string.IsNullOrWhiteSpace(PatientName) || PatientName.Length < 3)
      {
        throw new ArgumentException("Patient name is too short or empty.");
      }
      
      if (string.IsNullOrWhiteSpace(PatientBirthDate) || PatientBirthDate.Length != 8)
      {
        throw new ArgumentException("Birth date is not properly formatted (expected format: YYYYMMDD).");
      }
      
      if (string.IsNullOrWhiteSpace(Modality))
      {
        throw new ArgumentException("Modality cannot be empty.");
      }
      
      if (MonthsBack <= 0)
      {
        throw new ArgumentException("Months back should be a positive integer.");
      }
      
      var request = new DicomCFindRequest(DicomQueryRetrieveLevel.Study);
      
      var endDate = DateTime.Today;
      var startDate = endDate.AddMonths(-MonthsBack).ToString("yyyyMMdd");
      
      request.Dataset.AddOrUpdate(DicomTag.PatientName, PatientName);
      request.Dataset.AddOrUpdate(DicomTag.PatientBirthDate, PatientBirthDate);
      request.Dataset.AddOrUpdate(DicomTag.ModalitiesInStudy, Modality);
      request.Dataset.AddOrUpdate(DicomTag.StudyDate, $"{startDate}-{endDate:yyyyMMdd}");
      request.Dataset.AddOrUpdate(DicomTag.StudyInstanceUID, "");
      request.Dataset.AddOrUpdate(DicomTag.StudyDescription, "");
      request.Dataset.AddOrUpdate(DicomTag.SpecificCharacterSet, "ISO_IR 100");
      request.Dataset.AddOrUpdate(DicomTag.QueryRetrieveLevel, "STUDY");

      var client = new DicomClient(QrServerHost, QrServerPort, false, MyAE, QrServerAE);

      var responses = new List<DicomCFindResponse>();

      request.OnResponseReceived += (req, response) =>
      {
        responses.Add(response);
      };

      client.AddRequestAsync(request).GetAwaiter().GetResult();
      client.SendAsync().GetAwaiter().GetResult();

      WriteObject(responses);
    }    
  }
}
  
