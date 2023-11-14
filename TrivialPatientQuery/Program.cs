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

    static void Main(string[] args)
    {
      var request = new DicomCFindRequest(DicomQueryRetrieveLevel.Study);

      // Add tags as requested fields (without values)
      request.Dataset.AddOrUpdate(DicomTag.StudyDate, "");
      request.Dataset.AddOrUpdate(DicomTag.PatientID, "");
      request.Dataset.AddOrUpdate(DicomTag.StudyDescription, "");
      request.Dataset.AddOrUpdate(DicomTag.StudyInstanceUID, "");
      
      // Add tags with specific values to filter results
      request.Dataset.AddOrUpdate(DicomTag.PatientBirthDate, "18270326");
      request.Dataset.AddOrUpdate(DicomTag.PatientName, "BEETHOVEN^LUDWIG^VAN");
      
      // If you need to filter by modality or include it in the response
      request.Dataset.AddOrUpdate(DicomTag.ModalitiesInStudy, "CR");

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
