using System;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Collections.Generic;
using Dicom;
using Dicom.Network;
using DicomClient = Dicom.Network.Client.DicomClient;


namespace TrivialPatientQuery
{
  internal class Program
  {
    static string MyAE { get; set; } = "TRIVIAL";
    static string QRServerAE { get; set; } = "HOROS";
    static string QRServerHost { get; set; } = "localhost";
    static int QRServerPort { get; set; } = 2763;

    static public DicomCFindRequest CreateCFindRequest(
      string patientName,
      string birthDate,
      string modality,
      int monthsBack)
    {
      if (string.IsNullOrWhiteSpace(patientName) || patientName.Length < 3)
      {
        throw new ArgumentException("Patient name is too short or empty.");
      }
      
      if (string.IsNullOrWhiteSpace(birthDate) || birthDate.Length != 8)
      {
        throw new ArgumentException("Birth date is not properly formatted (expected format: YYYYMMDD).");
      }
      
      if (string.IsNullOrWhiteSpace(modality))
      {
        throw new ArgumentException("Modality cannot be empty.");
      }
      
      if (monthsBack <= 0)
      {
        throw new ArgumentException("Months back should be a positive integer.");
      }
      
      var request = new DicomCFindRequest(DicomQueryRetrieveLevel.Study);
      
      var endDate = DateTime.Today;
      var startDate = endDate.AddMonths(-monthsBack).ToString("yyyyMMdd");
      
      request.Dataset.AddOrUpdate(DicomTag.PatientName, patientName);
      request.Dataset.AddOrUpdate(DicomTag.PatientBirthDate, birthDate);
      request.Dataset.AddOrUpdate(DicomTag.ModalitiesInStudy, modality);
      request.Dataset.AddOrUpdate(DicomTag.StudyDate, $"{startDate}-{endDate:yyyyMMdd}");
      request.Dataset.AddOrUpdate(DicomTag.StudyInstanceUID, "");
      request.Dataset.AddOrUpdate(DicomTag.StudyDescription, "");
      request.Dataset.AddOrUpdate(DicomTag.SpecificCharacterSet, "ISO_IR 100");
      request.Dataset.AddOrUpdate(DicomTag.QueryRetrieveLevel, "STUDY");
      
      return request;
    }

    static void Main(string[] args)
    {
      // var request = new DicomCFindRequest(DicomQueryRetrieveLevel.Study);

      // // Add tags as requested fields (without values)
      // request.Dataset.AddOrUpdate(DicomTag.StudyDate, "");
      // request.Dataset.AddOrUpdate(DicomTag.PatientID, "");
      // request.Dataset.AddOrUpdate(DicomTag.StudyDescription, "");
      // request.Dataset.AddOrUpdate(DicomTag.StudyInstanceUID, "");
      
      // // Add tags with specific values to filter results
      // request.Dataset.AddOrUpdate(DicomTag.PatientBirthDate, "18270326");
      // request.Dataset.AddOrUpdate(DicomTag.PatientName, "BEETHOVEN^LUDWIG^VAN");
      
      // // If you need to filter by modality or include it in the response
      // request.Dataset.AddOrUpdate(DicomTag.ModalitiesInStudy, "CR");

      var request = CreateCFindRequest("BEETHOVEN^LUDWIG^VAN", "18270326", "CR", 60);
      
      var client = new DicomClient(
        QRServerHost,
        QRServerPort,
        false,
        MyAE,
        QRServerAE);

      var responses = new List<DicomCFindResponse>();

      request.OnResponseReceived += (req, response) =>
      {
        Console.WriteLine("Add a response...");
        responses.Add(response);
      };

      client.AddRequestAsync(request).GetAwaiter().GetResult();
      client.SendAsync().GetAwaiter().GetResult();

      Console.ReadLine(); // keep the window open.
    }
  }
}
