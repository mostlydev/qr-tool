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
    public string PatientName { get; set; }
    
    [Parameter(Mandatory = true)]
    public string PatientBirthDate { get; set; }
    
    [Parameter(Mandatory = true)]
    public string Modality { get; set; }
    
    [Parameter(Mandatory = true)]
    public int MonthsBack { get; set; }
    
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

        //if (response.Dataset is null)
        //{
        //  Console.WriteLine($"Add response with no dataset.");
        //}
        //else
        //{
        //  Console.WriteLine($"Add response with SUID {response.Dataset.GetSingleValue<string>(DicomTag.StudyInstanceUID)} "
        //    + $"and status {response.Status}...");
        //}
      };

      client.AddRequestAsync(request).GetAwaiter().GetResult();
      client.SendAsync().GetAwaiter().GetResult();

     // Console.WriteLine($"Return {responses.Count} responses.");

      WriteObject(responses);
    }    
  }

  [Cmdlet("Get", "ModalityWorklist")]
  public class GetModalityWorklistCmdlet : Cmdlet
  {
    [Parameter(Mandatory = true)]
    public string MyAE { get; set; }

    [Parameter(Mandatory = true)]
    public string WorklistServerAE { get; set; }

    [Parameter(Mandatory = true)]
    public string WorklistServerHost { get; set; }

    [Parameter(Mandatory = true)]
    public int WorklistServerPort { get; set; }

    [Parameter(Mandatory = false)]
    public string Modality { get; set; }

    [Parameter(Mandatory = false)]
    public string ScheduledDate { get; set; }

    protected override void ProcessRecord()
    {
      var request = new DicomCFindRequest(DicomQueryRetrieveLevel.NotApplicable);
      
      // Add required return keys for Modality Worklist
      request.Dataset.AddOrUpdate(DicomTag.PatientName, "");
      request.Dataset.AddOrUpdate(DicomTag.PatientID, "");
      request.Dataset.AddOrUpdate(DicomTag.PatientBirthDate, "");
      request.Dataset.AddOrUpdate(DicomTag.AccessionNumber, "");
      request.Dataset.AddOrUpdate(DicomTag.StudyInstanceUID, "");
      
      // Scheduled Procedure Step Sequence - this is required for MWL
      var scheduledProcedureStepSequence = new DicomSequence(DicomTag.ScheduledProcedureStepSequence);
      var scheduledProcedureStepItem = new DicomDataset();
      
      // Add items to the Scheduled Procedure Step Sequence
      scheduledProcedureStepItem.AddOrUpdate(DicomTag.ScheduledStationAETitle, "");
      scheduledProcedureStepItem.AddOrUpdate(DicomTag.ScheduledProcedureStepStartDate, "");
      scheduledProcedureStepItem.AddOrUpdate(DicomTag.ScheduledProcedureStepStartTime, "");
      scheduledProcedureStepItem.AddOrUpdate(DicomTag.ScheduledProcedureStepID, "");
      scheduledProcedureStepItem.AddOrUpdate(DicomTag.ScheduledProcedureStepDescription, "");
      
      // Add modality filter if specified
      if (!string.IsNullOrWhiteSpace(Modality))
      {
        scheduledProcedureStepItem.AddOrUpdate(DicomTag.Modality, Modality);
      }
      else
      {
        scheduledProcedureStepItem.AddOrUpdate(DicomTag.Modality, "");
      }
      
      // Add date filter if specified (format should be YYYYMMDD)
      if (!string.IsNullOrWhiteSpace(ScheduledDate))
      {
        scheduledProcedureStepItem.AddOrUpdate(DicomTag.ScheduledProcedureStepStartDate, ScheduledDate);
      }
      
      scheduledProcedureStepSequence.Items.Add(scheduledProcedureStepItem);
      request.Dataset.AddOrUpdate(scheduledProcedureStepSequence);
      
      // Set character set
      request.Dataset.AddOrUpdate(DicomTag.SpecificCharacterSet, "ISO_IR 100");
      request.Dataset.AddOrUpdate(DicomTag.QueryRetrieveLevel, "WORKLIST");

      var client = new DicomClient(WorklistServerHost, WorklistServerPort, false, MyAE, WorklistServerAE);

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
  
