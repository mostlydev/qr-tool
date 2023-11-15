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
    // [Parameter(Mandatory = true)]
    static public string MyAE { get; set; } = "QR-TOOL";

    // [Parameter(Mandatory = true)]
    static public string QrServerAE { get; set; } = "HOROS";

    // [Parameter(Mandatory = true)]
    static public string QrServerHost { get; set; } = "localhost";

    // [Parameter(Mandatory = true)]
    static public int QrServerPort { get; set; } = 2763;

    // [Parameter(Mandatory = true)]
    static public string PatientName { get; set; } = "BEETHOVEN^LUDWIG^VAN";

    // [Parameter(Mandatory = true)]
    static public string PatientBirthDate { get; set; } = "18270326";

    // [Parameter(Mandatory = true)]
    static public string Modality { get; set; } = "CR";

    // [Parameter(Mandatory = true)]
    static public int MonthsBack { get; set; } = 60;

    static void Main(string[] args)
    {
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

        if (response.Dataset is null)
        {
          Console.WriteLine($"Add response with no dataset.");
        }
        else
        {
          Console.WriteLine($"Add response with SUID {response.Dataset.GetSingleValue<string>(DicomTag.StudyInstanceUID)} "
            + $"and status {response.Status}...");
        }
      };

      client.AddRequestAsync(request).GetAwaiter().GetResult();
      client.SendAsync().GetAwaiter().GetResult();

      Console.WriteLine($"Return {responses.Count} responses.");

      Console.ReadLine(); // keep the window open.
    }
  }
}
